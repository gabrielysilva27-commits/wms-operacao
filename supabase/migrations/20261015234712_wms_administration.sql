BEGIN;
CREATE TABLE public.vehicle_bays(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses,
 vehicle_type_id uuid NOT NULL, code text NOT NULL, width_m numeric NOT NULL CHECK(width_m>0),
 depth_m numeric NOT NULL CHECK(depth_m>0), height_m numeric NOT NULL CHECK(height_m>0),
 max_weight_kg numeric NOT NULL CHECK(max_weight_kg>0), pallet_positions int NOT NULL CHECK(pallet_positions>0),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(warehouse_id,id), UNIQUE(warehouse_id,vehicle_type_id,code),
 FOREIGN KEY(warehouse_id,vehicle_type_id) REFERENCES public.vehicle_types(warehouse_id,id));
ALTER TABLE public.vehicle_bays ENABLE ROW LEVEL SECURITY;
GRANT SELECT,INSERT,UPDATE ON public.vehicle_bays TO authenticated;
CREATE POLICY member_read ON public.vehicle_bays FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE POLICY manage_insert ON public.vehicle_bays FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.vehicle_bays FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.vehicle_bays FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
CREATE OR REPLACE FUNCTION wms_private.guard_layout() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
DECLARE v uuid;
BEGIN
 IF TG_TABLE_NAME='addresses' THEN
 v:=COALESCE(NEW.layout_id,OLD.layout_id);
 IF EXISTS(SELECT 1 FROM public.layout_versions WHERE id=v AND state IN ('published','retired')) OR (TG_OP='UPDATE' AND EXISTS(SELECT 1 FROM public.layout_versions WHERE id=OLD.layout_id AND state IN ('published','retired'))) THEN RAISE EXCEPTION 'published layout is immutable; create a new version'; END IF;
 ELSE
 IF OLD.state IN ('published','retired') AND NOT(TG_OP='UPDATE' AND OLD.state='published' AND NEW.state='retired' AND NEW.id=OLD.id AND NEW.warehouse_id=OLD.warehouse_id AND NEW.version=OLD.version AND NEW.published_at IS NOT DISTINCT FROM OLD.published_at) THEN RAISE EXCEPTION 'published layout is immutable; create a new version'; END IF;
 END IF;
 RETURN COALESCE(NEW,OLD);
END $$;
CREATE FUNCTION public.publish_layout(w uuid,layout uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 IF NOT wms_private.manager(w) THEN RAISE EXCEPTION 'forbidden'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(w::text,0));
 IF NOT EXISTS(SELECT 1 FROM public.layout_versions WHERE warehouse_id=w AND id=layout AND state='draft') THEN RAISE EXCEPTION 'draft layout required'; END IF;
 UPDATE public.layout_versions SET state='retired' WHERE warehouse_id=w AND state='published';
 UPDATE public.layout_versions SET state='published',published_at=now() WHERE warehouse_id=w AND id=layout;
END $$;
CREATE FUNCTION public.set_membership(w uuid,target uuid,display_name text,member_role text,is_active boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 IF NOT wms_private.has_role(w,ARRAY['admin']) THEN RAISE EXCEPTION 'admin required'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(w::text,0));
 IF target=auth.uid() AND (member_role<>'admin' OR NOT is_active) AND (SELECT count(*) FROM public.memberships WHERE warehouse_id=w AND role='admin' AND active)<2 THEN RAISE EXCEPTION 'cannot remove last admin'; END IF;
 INSERT INTO public.memberships(warehouse_id,user_id,display_name,role,active) VALUES(w,target,display_name,member_role,is_active)
 ON CONFLICT(warehouse_id,user_id) DO UPDATE SET display_name=EXCLUDED.display_name,role=EXCLUDED.role,active=EXCLUDED.active;
 INSERT INTO public.events(warehouse_id,actor_id,entity_type,entity_id,event_type,payload) VALUES(w,auth.uid(),'membership',target,'membership_updated',jsonb_build_object('role',member_role,'active',is_active));
END $$;
CREATE FUNCTION public.record_observation(w uuid,p uuid,item uuid,started timestamptz,ended timestamptz,paused numeric) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result uuid;
BEGIN
 IF NOT wms_private.member(w) OR NOT EXISTS(SELECT 1 FROM public.assignments WHERE warehouse_id=w AND pallet_id=p AND user_id=auth.uid()) THEN RAISE EXCEPTION 'assignment required'; END IF;
 IF item IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.pallet_items WHERE warehouse_id=w AND id=item AND pallet_id=p) THEN RAISE EXCEPTION 'item mismatch'; END IF;
 INSERT INTO public.work_observations(warehouse_id,pallet_id,item_id,user_id,started_at,ended_at,pause_seconds) VALUES(w,p,item,auth.uid(),started,ended,paused) RETURNING id INTO result;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.publish_layout(uuid,uuid),public.set_membership(uuid,uuid,text,text,boolean),public.record_observation(uuid,uuid,uuid,timestamptz,timestamptz,numeric) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.publish_layout(uuid,uuid),public.set_membership(uuid,uuid,text,text,boolean),public.record_observation(uuid,uuid,uuid,timestamptz,timestamptz,numeric) TO authenticated;
REVOKE EXECUTE ON FUNCTION wms_private.audit(),wms_private.immutable(),wms_private.guard_layout(),wms_private.validate_item() FROM public,authenticated;
COMMIT;
