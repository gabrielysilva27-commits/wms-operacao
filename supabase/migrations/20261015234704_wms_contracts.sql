BEGIN;
-- Immutable published addressing: ongoing pallets keep their historical address/version.
CREATE FUNCTION wms_private.guard_layout() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
DECLARE v uuid;
BEGIN
 IF TG_TABLE_NAME='addresses' THEN v:=COALESCE(NEW.layout_id,OLD.layout_id); ELSE v:=COALESCE(NEW.id,OLD.id); END IF;
 IF EXISTS(SELECT 1 FROM public.layout_versions WHERE id=v AND state IN ('published','retired')) THEN RAISE EXCEPTION 'published layout is immutable; create a new version'; END IF;
 RETURN COALESCE(NEW,OLD);
END $$;
CREATE TRIGGER guard_layout BEFORE UPDATE OR DELETE ON public.layout_versions FOR EACH ROW EXECUTE FUNCTION wms_private.guard_layout();
CREATE TRIGGER guard_addresses BEFORE INSERT OR UPDATE OR DELETE ON public.addresses FOR EACH ROW EXECUTE FUNCTION wms_private.guard_layout();
CREATE FUNCTION wms_private.validate_item() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.palletization_versions WHERE warehouse_id=NEW.warehouse_id AND id=NEW.palletization_id AND product_id=NEW.product_id) THEN RAISE EXCEPTION 'palletization product mismatch'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.addresses WHERE warehouse_id=NEW.warehouse_id AND id=NEW.picking_address_id AND zone='picking') THEN RAISE EXCEPTION 'picking address required'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER validate_item BEFORE INSERT OR UPDATE ON public.pallet_items FOR EACH ROW EXECUTE FUNCTION wms_private.validate_item();
CREATE FUNCTION public.reserve_media(w uuid,p uuid,l uuid,mime text,bytes bigint,caption text) RETURNS public.media_records LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result public.media_records; media_id uuid:=gen_random_uuid();
BEGIN
 IF NOT wms_private.has_role(w,ARRAY['admin','supervisor','helper','checker','forklift','recorder']) THEN RAISE EXCEPTION 'forbidden'; END IF;
 INSERT INTO public.media_records(id,warehouse_id,pallet_id,load_id,uploaded_by,object_path,content_type,size_bytes,caption)
 VALUES(media_id,w,p,l,auth.uid(),w::text||'/'||auth.uid()::text||'/'||media_id::text,mime,bytes,caption) RETURNING * INTO result;
 RETURN result;
END $$;
CREATE FUNCTION public.finalize_media(w uuid,m uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 UPDATE public.media_records r SET state='uploaded' WHERE r.warehouse_id=w AND r.id=m AND r.uploaded_by=auth.uid() AND wms_private.member(w) AND EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='wms-evidence' AND o.name=r.object_path);
 IF NOT FOUND THEN RAISE EXCEPTION 'upload missing or forbidden'; END IF;
END $$;
-- These functions are agent-only; lease tokens fence stale workers.
DROP TRIGGER immutable_record ON public.integration_attempts;
CREATE FUNCTION wms_private.finish_job(job uuid,token uuid,outcome text,response jsonb,error_summary text DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j public.integration_jobs; next_state text;
BEGIN
 SELECT * INTO j FROM public.integration_jobs WHERE id=job AND lease_token=token AND state='running' AND lease_until>now() FOR UPDATE;
 IF j.id IS NULL THEN RAISE EXCEPTION 'expired lease'; END IF;
 IF outcome NOT IN ('succeeded','retry','uncertain','permanent') THEN RAISE EXCEPTION 'invalid outcome'; END IF;
 next_state:=CASE WHEN outcome='succeeded' THEN 'succeeded' WHEN outcome='uncertain' THEN 'manual_review' WHEN outcome='permanent' OR j.attempts>=j.max_attempts THEN 'dead' ELSE 'retry_wait' END;
 UPDATE public.integration_jobs SET state=next_state,result=response,last_error=left(error_summary,2000),lease_token=NULL,lease_until=NULL,next_attempt_at=now()+make_interval(secs=>least(3600,power(2,j.attempts)::int*15)) WHERE id=job;
 UPDATE public.integration_attempts SET ended_at=now(),outcome=finish_job.outcome,sanitized_log=jsonb_build_object('summary',left(error_summary,2000)) WHERE job_id=job AND attempt=j.attempts;
END $$;
CREATE FUNCTION wms_private.reap_expired_jobs() RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE count_rows int;
BEGIN
 -- Never repeat a possibly completed external side effect without reconciliation.
 UPDATE public.integration_jobs SET state='manual_review',last_error='lease expired; reconcile external state before retry',lease_token=NULL,lease_until=NULL WHERE state='running' AND lease_until<now();
 GET DIAGNOSTICS count_rows=ROW_COUNT; RETURN count_rows;
END $$;
REVOKE ALL ON FUNCTION public.reserve_media(uuid,uuid,uuid,text,bigint,text),public.finalize_media(uuid,uuid) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.reserve_media(uuid,uuid,uuid,text,bigint,text),public.finalize_media(uuid,uuid) TO authenticated;
REVOKE ALL ON FUNCTION wms_private.finish_job(uuid,uuid,text,jsonb,text),wms_private.reap_expired_jobs() FROM public,authenticated;
GRANT EXECUTE ON FUNCTION wms_private.finish_job(uuid,uuid,text,jsonb,text),wms_private.reap_expired_jobs() TO service_role;
COMMIT;
