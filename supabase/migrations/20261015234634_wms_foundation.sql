-- WMS isolated foundation. Apply ONLY to a new dedicated Supabase project.
BEGIN;
CREATE SCHEMA IF NOT EXISTS wms_private;
REVOKE ALL ON SCHEMA wms_private FROM public;
CREATE TABLE public.warehouses(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, timezone text NOT NULL DEFAULT 'America/Sao_Paulo', created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.memberships(warehouse_id uuid NOT NULL REFERENCES public.warehouses, user_id uuid NOT NULL REFERENCES auth.users, display_name text NOT NULL, role text NOT NULL CHECK(role IN ('admin','supervisor','helper','checker','forklift','recorder','viewer')), active boolean NOT NULL DEFAULT true, PRIMARY KEY(warehouse_id,user_id));
CREATE FUNCTION wms_private.member(w uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT EXISTS(SELECT 1 FROM public.memberships WHERE warehouse_id=w AND user_id=(SELECT auth.uid()) AND active) $$;
CREATE FUNCTION wms_private.manager(w uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT EXISTS(SELECT 1 FROM public.memberships WHERE warehouse_id=w AND user_id=(SELECT auth.uid()) AND active AND role IN ('admin','supervisor')) $$;
CREATE FUNCTION wms_private.has_role(w uuid, roles text[]) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT EXISTS(SELECT 1 FROM public.memberships WHERE warehouse_id=w AND user_id=(SELECT auth.uid()) AND active AND role=ANY(roles)) $$;
GRANT USAGE ON SCHEMA wms_private TO authenticated,service_role;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA wms_private FROM public;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA wms_private TO authenticated;
CREATE TABLE public.skills(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), code text NOT NULL, name text NOT NULL, UNIQUE(warehouse_id,code), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.skills(warehouse_id);
CREATE TABLE public.worker_skills(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), user_id uuid NOT NULL, skill_id uuid NOT NULL, level int NOT NULL DEFAULT 1 CHECK(level BETWEEN 1 AND 5), valid_until timestamptz, FOREIGN KEY(warehouse_id,user_id) REFERENCES public.memberships(warehouse_id,user_id), FOREIGN KEY(warehouse_id,skill_id) REFERENCES public.skills(warehouse_id,id), UNIQUE(warehouse_id,user_id,skill_id), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.worker_skills(warehouse_id);
CREATE TABLE public.presence(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), user_id uuid NOT NULL, shift text NOT NULL CHECK(shift IN ('A','B','C')), state text NOT NULL CHECK(state IN ('available','busy','break','absent')), starts_at timestamptz NOT NULL DEFAULT now(), ends_at timestamptz, CHECK(ends_at IS NULL OR ends_at>starts_at), FOREIGN KEY(warehouse_id,user_id) REFERENCES public.memberships(warehouse_id,user_id), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.presence(warehouse_id);
CREATE TABLE public.products(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), sku text NOT NULL, description text NOT NULL, unit text NOT NULL DEFAULT 'CX', active boolean NOT NULL DEFAULT true, UNIQUE(warehouse_id,sku), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.products(warehouse_id);
CREATE TABLE public.palletization_versions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), product_id uuid NOT NULL, version int NOT NULL CHECK(version>0), boxes_per_layer int NOT NULL CHECK(boxes_per_layer>0), layers int NOT NULL CHECK(layers>0), box_weight_kg numeric NOT NULL CHECK(box_weight_kg>0), box_volume_m3 numeric NOT NULL CHECK(box_volume_m3>0), max_height_m numeric CHECK(max_height_m>0), valid_from timestamptz NOT NULL DEFAULT now(), FOREIGN KEY(warehouse_id,product_id) REFERENCES public.products(warehouse_id,id), UNIQUE(warehouse_id,product_id,version), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.palletization_versions(warehouse_id);
CREATE TABLE public.vehicle_types(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), name text NOT NULL, max_weight_kg numeric NOT NULL CHECK(max_weight_kg>0), max_volume_m3 numeric NOT NULL CHECK(max_volume_m3>0), pallet_positions int NOT NULL CHECK(pallet_positions>0), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.vehicle_types(warehouse_id);
CREATE TABLE public.vehicles(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), plate text NOT NULL, type_id uuid NOT NULL, active boolean NOT NULL DEFAULT true, FOREIGN KEY(warehouse_id,type_id) REFERENCES public.vehicle_types(warehouse_id,id), UNIQUE(warehouse_id,plate), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.vehicles(warehouse_id);
CREATE TABLE public.layout_versions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), version int NOT NULL CHECK(version>0), state text NOT NULL DEFAULT 'draft' CHECK(state IN ('draft','published','retired')), published_at timestamptz, UNIQUE(warehouse_id,version), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.layout_versions(warehouse_id);
CREATE TABLE public.addresses(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), layout_id uuid NOT NULL, code text NOT NULL, zone text NOT NULL CHECK(zone IN ('picking','storage','staging','dock','quarantine')), aisle text, position int, level int, x numeric, y numeric, capacity_pallets int CHECK(capacity_pallets>0), FOREIGN KEY(warehouse_id,layout_id) REFERENCES public.layout_versions(warehouse_id,id), UNIQUE(warehouse_id,layout_id,code), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.addresses(warehouse_id);
CREATE TABLE public.product_addresses(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), product_id uuid NOT NULL, address_id uuid NOT NULL, FOREIGN KEY(warehouse_id,product_id) REFERENCES public.products(warehouse_id,id), FOREIGN KEY(warehouse_id,address_id) REFERENCES public.addresses(warehouse_id,id), UNIQUE(warehouse_id,product_id,address_id), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.product_addresses(warehouse_id);
CREATE TABLE public.loads(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), code text NOT NULL, vehicle_id uuid, state text NOT NULL DEFAULT 'planning' CHECK(state IN ('planning','released','building','staged','physically_loaded','closed')), FOREIGN KEY(warehouse_id,vehicle_id) REFERENCES public.vehicles(warehouse_id,id), UNIQUE(warehouse_id,code), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.loads(warehouse_id);
CREATE TABLE public.maps(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), load_id uuid NOT NULL, code text NOT NULL, priority int NOT NULL CHECK(priority>=0), priority_reason text NOT NULL, priority_version int NOT NULL DEFAULT 1 CHECK(priority_version>0), released boolean NOT NULL DEFAULT false, scheduled_at timestamptz, FOREIGN KEY(warehouse_id,load_id) REFERENCES public.loads(warehouse_id,id), UNIQUE(warehouse_id,code), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.maps(warehouse_id);
CREATE TABLE public.effort_models(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), version int NOT NULL CHECK(version>0), name text NOT NULL, base_seconds numeric NOT NULL CHECK(base_seconds>=0), seconds_per_box numeric NOT NULL CHECK(seconds_per_box>=0), seconds_per_meter numeric NOT NULL CHECK(seconds_per_meter>=0), sample_count int NOT NULL DEFAULT 0 CHECK(sample_count>=0), calibration_notes text, UNIQUE(warehouse_id,version), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.effort_models(warehouse_id);
CREATE TABLE public.pallets(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), map_id uuid NOT NULL, code text NOT NULL, skill_id uuid NOT NULL, effort_model_id uuid NOT NULL, standard_seconds numeric NOT NULL CHECK(standard_seconds>0), state text NOT NULL DEFAULT 'queued' CHECK(state IN ('queued','assigned','building','staged','loaded')), staging_address_id uuid, FOREIGN KEY(warehouse_id,map_id) REFERENCES public.maps(warehouse_id,id), FOREIGN KEY(warehouse_id,skill_id) REFERENCES public.skills(warehouse_id,id), FOREIGN KEY(warehouse_id,effort_model_id) REFERENCES public.effort_models(warehouse_id,id), FOREIGN KEY(warehouse_id,staging_address_id) REFERENCES public.addresses(warehouse_id,id), UNIQUE(warehouse_id,map_id,code), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.pallets(warehouse_id);
CREATE TABLE public.pallet_items(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), pallet_id uuid NOT NULL, product_id uuid NOT NULL, palletization_id uuid NOT NULL, picking_address_id uuid NOT NULL, planned_qty numeric NOT NULL CHECK(planned_qty>0), picked_qty numeric NOT NULL DEFAULT 0 CHECK(picked_qty>=0), standard_seconds numeric NOT NULL CHECK(standard_seconds>=0), FOREIGN KEY(warehouse_id,pallet_id) REFERENCES public.pallets(warehouse_id,id), FOREIGN KEY(warehouse_id,product_id) REFERENCES public.products(warehouse_id,id), FOREIGN KEY(warehouse_id,palletization_id) REFERENCES public.palletization_versions(warehouse_id,id), FOREIGN KEY(warehouse_id,picking_address_id) REFERENCES public.addresses(warehouse_id,id), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.pallet_items(warehouse_id);
CREATE TABLE public.assignments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), pallet_id uuid NOT NULL, user_id uuid NOT NULL, state text NOT NULL DEFAULT 'active' CHECK(state IN ('active','completed','cancelled')), standard_seconds numeric NOT NULL CHECK(standard_seconds>0), draw_id uuid NOT NULL, assigned_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz, FOREIGN KEY(warehouse_id,pallet_id) REFERENCES public.pallets(warehouse_id,id), FOREIGN KEY(warehouse_id,user_id) REFERENCES public.memberships(warehouse_id,user_id), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.assignments(warehouse_id);
CREATE TABLE public.priority_draws(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), request_key uuid NOT NULL, pallet_id uuid NOT NULL, priority_snapshot jsonb NOT NULL, candidates jsonb NOT NULL, selected_user uuid NOT NULL, random_token uuid NOT NULL, balance_window_seconds numeric NOT NULL CHECK(balance_window_seconds>=0), UNIQUE(warehouse_id,request_key), FOREIGN KEY(warehouse_id,pallet_id) REFERENCES public.pallets(warehouse_id,id), FOREIGN KEY(warehouse_id,selected_user) REFERENCES public.memberships(warehouse_id,user_id), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.priority_draws(warehouse_id);
CREATE TABLE public.check_issues(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), pallet_id uuid NOT NULL, item_id uuid, helper_id uuid NOT NULL, checker_id uuid NOT NULL, kind text NOT NULL CHECK(kind IN ('shortage','excess','damage','other')), quantity numeric CHECK(quantity>0), note text NOT NULL, state text NOT NULL DEFAULT 'open' CHECK(state IN ('open','resolved')), resolution text, resolved_at timestamptz, FOREIGN KEY(warehouse_id,pallet_id) REFERENCES public.pallets(warehouse_id,id), FOREIGN KEY(warehouse_id,item_id) REFERENCES public.pallet_items(warehouse_id,id), FOREIGN KEY(warehouse_id,helper_id) REFERENCES public.memberships(warehouse_id,user_id), FOREIGN KEY(warehouse_id,checker_id) REFERENCES public.memberships(warehouse_id,user_id), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.check_issues(warehouse_id);
CREATE TABLE public.work_observations(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), pallet_id uuid NOT NULL, item_id uuid, user_id uuid NOT NULL, started_at timestamptz NOT NULL, ended_at timestamptz NOT NULL, pause_seconds numeric NOT NULL DEFAULT 0 CHECK(pause_seconds>=0), actual_seconds numeric GENERATED ALWAYS AS (extract(epoch FROM ended_at-started_at)-pause_seconds) STORED, CHECK(ended_at>started_at AND pause_seconds<extract(epoch FROM ended_at-started_at)), FOREIGN KEY(warehouse_id,pallet_id) REFERENCES public.pallets(warehouse_id,id), FOREIGN KEY(warehouse_id,item_id) REFERENCES public.pallet_items(warehouse_id,id), FOREIGN KEY(warehouse_id,user_id) REFERENCES public.memberships(warehouse_id,user_id), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.work_observations(warehouse_id);
CREATE TABLE public.media_records(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), pallet_id uuid, load_id uuid, uploaded_by uuid NOT NULL, object_path text NOT NULL UNIQUE, content_type text NOT NULL CHECK(content_type IN ('image/jpeg','image/png','image/webp','video/mp4')), size_bytes bigint NOT NULL CHECK(size_bytes BETWEEN 1 AND 52428800), state text NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','uploaded','failed')), caption text NOT NULL DEFAULT '', captured_at timestamptz NOT NULL DEFAULT now(), FOREIGN KEY(warehouse_id,pallet_id) REFERENCES public.pallets(warehouse_id,id), FOREIGN KEY(warehouse_id,load_id) REFERENCES public.loads(warehouse_id,id), FOREIGN KEY(warehouse_id,uploaded_by) REFERENCES public.memberships(warehouse_id,user_id), CHECK(pallet_id IS NOT NULL OR load_id IS NOT NULL), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.media_records(warehouse_id);
CREATE TABLE public.integration_jobs(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), adapter text NOT NULL CHECK(adapter IN ('romaneio','cora','ocp','promax')), operation text NOT NULL, entity_id uuid NOT NULL, idempotency_key text NOT NULL, payload jsonb NOT NULL, payload_version int NOT NULL DEFAULT 1, state text NOT NULL DEFAULT 'disabled' CHECK(state IN ('disabled','queued','running','retry_wait','succeeded','dead','manual_review')), attempts int NOT NULL DEFAULT 0, max_attempts int NOT NULL DEFAULT 5 CHECK(max_attempts>0), next_attempt_at timestamptz NOT NULL DEFAULT now(), lease_until timestamptz, lease_token uuid, last_error text, result jsonb, CONSTRAINT job_dedupe UNIQUE(warehouse_id,adapter,operation,idempotency_key), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.integration_jobs(warehouse_id);
CREATE TABLE public.integration_attempts(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), job_id uuid NOT NULL, attempt int NOT NULL, started_at timestamptz NOT NULL DEFAULT now(), ended_at timestamptz, outcome text, sanitized_log jsonb NOT NULL DEFAULT '{}', FOREIGN KEY(warehouse_id,job_id) REFERENCES public.integration_jobs(warehouse_id,id), UNIQUE(warehouse_id,job_id,attempt), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.integration_attempts(warehouse_id);
CREATE TABLE public.events(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), actor_id uuid, entity_type text NOT NULL, entity_id uuid NOT NULL, event_type text NOT NULL, payload jsonb NOT NULL, occurred_at timestamptz NOT NULL DEFAULT now(), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.events(warehouse_id);
CREATE TABLE public.audit_log(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), warehouse_id uuid NOT NULL REFERENCES public.warehouses, created_at timestamptz NOT NULL DEFAULT now(), actor_id uuid, table_name text NOT NULL, row_id uuid NOT NULL, action text NOT NULL, old_value jsonb, new_value jsonb, occurred_at timestamptz NOT NULL DEFAULT now(), UNIQUE(warehouse_id,id));
CREATE INDEX ON public.audit_log(warehouse_id);
CREATE UNIQUE INDEX one_current_presence ON public.presence(warehouse_id,user_id) WHERE ends_at IS NULL;
CREATE UNIQUE INDEX one_active_pallet_assignment ON public.assignments(warehouse_id,pallet_id) WHERE state='active';
CREATE UNIQUE INDEX one_active_worker_assignment ON public.assignments(warehouse_id,user_id) WHERE state='active';
CREATE UNIQUE INDEX one_published_layout ON public.layout_versions(warehouse_id) WHERE state='published';
CREATE INDEX jobs_ready ON public.integration_jobs(next_attempt_at) WHERE state IN ('queued','retry_wait');
CREATE INDEX issue_search ON public.check_issues(warehouse_id,state,created_at DESC);
CREATE INDEX media_search ON public.media_records(warehouse_id,captured_at DESC);
CREATE INDEX maps_priority ON public.maps(warehouse_id,priority DESC,scheduled_at,created_at) WHERE released;
CREATE INDEX observations_calibration ON public.work_observations(warehouse_id,pallet_id);
ALTER TABLE public.assignments ADD FOREIGN KEY(warehouse_id,draw_id) REFERENCES public.priority_draws(warehouse_id,id);
CREATE FUNCTION wms_private.audit() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.audit_log(warehouse_id,actor_id,table_name,row_id,action,old_value,new_value)
 VALUES(COALESCE(NEW.warehouse_id,OLD.warehouse_id),auth.uid(),TG_TABLE_NAME,COALESCE(NEW.id,OLD.id),TG_OP,CASE WHEN TG_OP<>'INSERT' THEN to_jsonb(OLD) END,CASE WHEN TG_OP<>'DELETE' THEN to_jsonb(NEW) END);
 RETURN COALESCE(NEW,OLD);
END $$;
CREATE FUNCTION wms_private.immutable() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$ BEGIN RAISE EXCEPTION 'immutable record; append a new version/event'; END $$;
ALTER TABLE public.skills ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.skills TO authenticated;
CREATE POLICY member_read ON public.skills FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.skills FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.worker_skills ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.worker_skills TO authenticated;
CREATE POLICY member_read ON public.worker_skills FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.worker_skills FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.presence ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.presence TO authenticated;
CREATE POLICY member_read ON public.presence FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.presence FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.products TO authenticated;
CREATE POLICY member_read ON public.products FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.products FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.palletization_versions ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.palletization_versions TO authenticated;
CREATE POLICY member_read ON public.palletization_versions FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.palletization_versions FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.vehicle_types ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.vehicle_types TO authenticated;
CREATE POLICY member_read ON public.vehicle_types FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.vehicle_types FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.vehicles TO authenticated;
CREATE POLICY member_read ON public.vehicles FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.vehicles FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.layout_versions ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.layout_versions TO authenticated;
CREATE POLICY member_read ON public.layout_versions FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.layout_versions FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.addresses TO authenticated;
CREATE POLICY member_read ON public.addresses FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.addresses FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.product_addresses ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.product_addresses TO authenticated;
CREATE POLICY member_read ON public.product_addresses FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.product_addresses FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.loads ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.loads TO authenticated;
CREATE POLICY member_read ON public.loads FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.loads FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.maps ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.maps TO authenticated;
CREATE POLICY member_read ON public.maps FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.maps FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.effort_models ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.effort_models TO authenticated;
CREATE POLICY member_read ON public.effort_models FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.effort_models FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.pallets ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.pallets TO authenticated;
CREATE POLICY member_read ON public.pallets FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.pallets FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.pallet_items ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.pallet_items TO authenticated;
CREATE POLICY member_read ON public.pallet_items FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.pallet_items FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.assignments TO authenticated;
CREATE POLICY member_read ON public.assignments FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.assignments FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.priority_draws ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.priority_draws TO authenticated;
CREATE POLICY member_read ON public.priority_draws FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.priority_draws FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.check_issues ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.check_issues TO authenticated;
CREATE POLICY member_read ON public.check_issues FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.check_issues FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.work_observations ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.work_observations TO authenticated;
CREATE POLICY member_read ON public.work_observations FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.work_observations FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.media_records ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.media_records TO authenticated;
CREATE POLICY member_read ON public.media_records FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.media_records FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.integration_jobs ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.integration_jobs TO authenticated;
CREATE POLICY member_read ON public.integration_jobs FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.integration_jobs FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.integration_attempts ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.integration_attempts TO authenticated;
CREATE POLICY member_read ON public.integration_attempts FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
CREATE TRIGGER audit_changes AFTER INSERT OR UPDATE OR DELETE ON public.integration_attempts FOR EACH ROW EXECUTE FUNCTION wms_private.audit();
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.events TO authenticated;
CREATE POLICY member_read ON public.events FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.audit_log TO authenticated;
CREATE POLICY member_read ON public.audit_log FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
GRANT INSERT,UPDATE ON public.skills TO authenticated;
CREATE POLICY manage_insert ON public.skills FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.skills FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.worker_skills TO authenticated;
CREATE POLICY manage_insert ON public.worker_skills FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.worker_skills FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.products TO authenticated;
CREATE POLICY manage_insert ON public.products FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.products FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.palletization_versions TO authenticated;
CREATE POLICY manage_insert ON public.palletization_versions FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.palletization_versions FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.vehicle_types TO authenticated;
CREATE POLICY manage_insert ON public.vehicle_types FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.vehicle_types FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.vehicles TO authenticated;
CREATE POLICY manage_insert ON public.vehicles FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.vehicles FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.layout_versions TO authenticated;
CREATE POLICY manage_insert ON public.layout_versions FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.layout_versions FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.addresses TO authenticated;
CREATE POLICY manage_insert ON public.addresses FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.addresses FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.product_addresses TO authenticated;
CREATE POLICY manage_insert ON public.product_addresses FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.product_addresses FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.loads TO authenticated;
CREATE POLICY manage_insert ON public.loads FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.loads FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.maps TO authenticated;
CREATE POLICY manage_insert ON public.maps FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.maps FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.effort_models TO authenticated;
CREATE POLICY manage_insert ON public.effort_models FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.effort_models FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.pallets TO authenticated;
CREATE POLICY manage_insert ON public.pallets FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.pallets FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
GRANT INSERT,UPDATE ON public.pallet_items TO authenticated;
CREATE POLICY manage_insert ON public.pallet_items FOR INSERT TO authenticated WITH CHECK(wms_private.manager(warehouse_id));
CREATE POLICY manage_update ON public.pallet_items FOR UPDATE TO authenticated USING(wms_private.manager(warehouse_id)) WITH CHECK(wms_private.manager(warehouse_id));
CREATE TRIGGER immutable_record BEFORE UPDATE OR DELETE ON public.events FOR EACH ROW EXECUTE FUNCTION wms_private.immutable();
CREATE TRIGGER immutable_record BEFORE UPDATE OR DELETE ON public.audit_log FOR EACH ROW EXECUTE FUNCTION wms_private.immutable();
CREATE TRIGGER immutable_record BEFORE UPDATE OR DELETE ON public.priority_draws FOR EACH ROW EXECUTE FUNCTION wms_private.immutable();
CREATE TRIGGER immutable_record BEFORE UPDATE OR DELETE ON public.palletization_versions FOR EACH ROW EXECUTE FUNCTION wms_private.immutable();
CREATE TRIGGER immutable_record BEFORE UPDATE OR DELETE ON public.effort_models FOR EACH ROW EXECUTE FUNCTION wms_private.immutable();
CREATE TRIGGER immutable_record BEFORE UPDATE OR DELETE ON public.work_observations FOR EACH ROW EXECUTE FUNCTION wms_private.immutable();
CREATE TRIGGER immutable_record BEFORE UPDATE OR DELETE ON public.integration_attempts FOR EACH ROW EXECUTE FUNCTION wms_private.immutable();
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.warehouses,public.memberships TO authenticated;
CREATE POLICY member_read ON public.warehouses FOR SELECT TO authenticated USING(wms_private.member(id));
CREATE POLICY member_read ON public.memberships FOR SELECT TO authenticated USING(wms_private.member(warehouse_id));
-- No client self-enrollment or role editing. Bootstrap via trusted SQL/admin provisioning.
CREATE FUNCTION public.set_presence(w uuid, target uuid, new_state text, shift_code text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result uuid;
BEGIN
 IF NOT wms_private.manager(w) AND NOT(target=auth.uid() AND wms_private.member(w)) THEN RAISE EXCEPTION 'forbidden'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(w::text,0));
 IF new_state='available' AND EXISTS(SELECT 1 FROM public.assignments WHERE warehouse_id=w AND user_id=target AND state='active') THEN RAISE EXCEPTION 'active assignment'; END IF;
 UPDATE public.presence SET ends_at=now() WHERE warehouse_id=w AND user_id=target AND ends_at IS NULL;
 INSERT INTO public.presence(warehouse_id,user_id,state,shift) VALUES(w,target,new_state,shift_code) RETURNING id INTO result;
 RETURN result;
END $$;
-- Serialize dispatch per warehouse; preserve priority BEFORE considering people.
CREATE FUNCTION public.dispatch_next(w uuid, request_key uuid, balance_window numeric DEFAULT 600) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.pallets; m public.maps; minimum numeric; candidates jsonb; chosen uuid; draw uuid; token uuid:=gen_random_uuid(); entropy bigint; candidate_count int; existing public.priority_draws;
BEGIN
 IF NOT wms_private.manager(w) THEN RAISE EXCEPTION 'forbidden'; END IF;
 IF balance_window<0 OR balance_window>7200 THEN RAISE EXCEPTION 'invalid balance window'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(w::text,0));
 SELECT * INTO existing FROM public.priority_draws d WHERE d.warehouse_id=w AND d.request_key=dispatch_next.request_key;
 IF FOUND THEN RETURN jsonb_build_object('draw_id',existing.id,'pallet_id',existing.pallet_id,'user_id',existing.selected_user,'replayed',true); END IF;
 SELECT x.* INTO p FROM public.pallets x JOIN public.maps y ON y.id=x.map_id AND y.warehouse_id=x.warehouse_id
 WHERE x.warehouse_id=w AND x.state='queued' AND y.released
 ORDER BY y.priority DESC,y.scheduled_at NULLS LAST,y.created_at,y.id,x.created_at,x.id LIMIT 1 FOR UPDATE OF x;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','no_work'); END IF;
 SELECT * INTO m FROM public.maps WHERE id=p.map_id;
 WITH eligible AS (
 SELECT u.user_id,COALESCE((SELECT sum(a.standard_seconds) FROM public.assignments a WHERE a.warehouse_id=w AND a.user_id=u.user_id AND a.state<>'cancelled' AND (a.assigned_at AT TIME ZONE wh.timezone)::date=(now() AT TIME ZONE wh.timezone)::date),0) AS effort
 FROM public.memberships u JOIN public.warehouses wh ON wh.id=u.warehouse_id
 JOIN public.presence pr ON pr.warehouse_id=u.warehouse_id AND pr.user_id=u.user_id AND pr.ends_at IS NULL AND pr.state='available'
 JOIN public.worker_skills sk ON sk.warehouse_id=u.warehouse_id AND sk.user_id=u.user_id AND sk.skill_id=p.skill_id AND (sk.valid_until IS NULL OR sk.valid_until>now())
 WHERE u.warehouse_id=w AND u.active AND u.role IN ('helper','forklift') AND NOT EXISTS(SELECT 1 FROM public.assignments a WHERE a.warehouse_id=w AND a.user_id=u.user_id AND a.state='active'))
 SELECT jsonb_agg(jsonb_build_object('user_id',user_id,'effort_seconds',effort)),min(effort) INTO candidates,minimum FROM eligible;
 IF candidates IS NULL THEN RETURN jsonb_build_object('status','awaiting_eligible_worker','pallet_id',p.id,'priority',m.priority); END IF;
 SELECT jsonb_agg(value) INTO candidates FROM jsonb_array_elements(candidates) WHERE (value->>'effort_seconds')::numeric<=minimum+balance_window;
 -- UUID entropy supplied by PostgreSQL; uniform bucket selection among balanced candidates.
 candidate_count:=jsonb_array_length(candidates);
 LOOP
 token:=gen_random_uuid();
 entropy:=('x'||substr(replace(token::text,'-',''),1,8))::bit(32)::bigint;
 EXIT WHEN entropy<floor(4294967296::numeric/candidate_count)*candidate_count;
 END LOOP;
 SELECT (value->>'user_id')::uuid INTO chosen FROM jsonb_array_elements(candidates) WITH ORDINALITY t(value,n)
 WHERE n=1+(entropy % candidate_count);
 INSERT INTO public.priority_draws(warehouse_id,request_key,pallet_id,priority_snapshot,candidates,selected_user,random_token,balance_window_seconds)
 VALUES(w,request_key,p.id,jsonb_build_object('map_id',m.id,'priority',m.priority,'version',m.priority_version,'reason',m.priority_reason),candidates,chosen,token,balance_window) RETURNING id INTO draw;
 INSERT INTO public.assignments(warehouse_id,pallet_id,user_id,standard_seconds,draw_id) VALUES(w,p.id,chosen,p.standard_seconds,draw);
 UPDATE public.pallets SET state='assigned' WHERE id=p.id;
 UPDATE public.presence SET ends_at=now() WHERE warehouse_id=w AND user_id=chosen AND ends_at IS NULL;
 INSERT INTO public.presence(warehouse_id,user_id,state,shift) SELECT w,chosen,'busy',shift FROM public.presence WHERE warehouse_id=w AND user_id=chosen ORDER BY starts_at DESC LIMIT 1;
 INSERT INTO public.events(warehouse_id,actor_id,entity_type,entity_id,event_type,payload) VALUES(w,auth.uid(),'pallet',p.id,'assigned',jsonb_build_object('draw_id',draw,'user_id',chosen));
 RETURN jsonb_build_object('draw_id',draw,'pallet_id',p.id,'user_id',chosen,'replayed',false);
END $$;
CREATE FUNCTION public.report_issue(w uuid,p uuid,kind text,qty numeric,note text,item uuid DEFAULT NULL) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE helper uuid; result uuid;
BEGIN
 IF NOT wms_private.has_role(w,ARRAY['checker','admin','supervisor']) THEN RAISE EXCEPTION 'forbidden'; END IF;
 SELECT user_id INTO helper FROM public.assignments WHERE warehouse_id=w AND pallet_id=p AND state IN ('active','completed') ORDER BY assigned_at DESC LIMIT 1;
 IF helper IS NULL THEN RAISE EXCEPTION 'pallet has no helper'; END IF;
 IF item IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.pallet_items WHERE warehouse_id=w AND id=item AND pallet_id=p) THEN RAISE EXCEPTION 'item mismatch'; END IF;
 INSERT INTO public.check_issues(warehouse_id,pallet_id,item_id,helper_id,checker_id,kind,quantity,note) VALUES(w,p,item,helper,auth.uid(),kind,qty,note) RETURNING id INTO result;
 -- Intentionally does not change pallet state, presence or assignment.
 RETURN result;
END $$;
CREATE FUNCTION public.resolve_issue(w uuid,issue uuid,resolution text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF length(trim(resolution))=0 THEN RAISE EXCEPTION 'resolution required'; END IF;
 UPDATE public.check_issues i SET state='resolved',resolution=resolve_issue.resolution,resolved_at=now()
 WHERE i.warehouse_id=w AND i.id=issue AND i.state='open' AND wms_private.member(w) AND (i.checker_id=auth.uid() OR wms_private.manager(w));
 IF NOT FOUND THEN RAISE EXCEPTION 'issue unavailable or forbidden'; END IF;
END $$;
CREATE FUNCTION public.complete_pallet(w uuid,p uuid,staging uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a public.assignments; sh text; current_presence text;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(w::text,0));
 SELECT * INTO a FROM public.assignments WHERE warehouse_id=w AND pallet_id=p AND state='active' FOR UPDATE;
 IF a.id IS NULL OR NOT wms_private.member(w) OR NOT(a.user_id=auth.uid() OR wms_private.manager(w)) THEN RAISE EXCEPTION 'forbidden or no active assignment'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.addresses ad JOIN public.layout_versions lv ON lv.id=ad.layout_id WHERE ad.warehouse_id=w AND ad.id=staging AND ad.zone='staging' AND lv.state='published') THEN RAISE EXCEPTION 'invalid staging'; END IF;
 UPDATE public.assignments SET state='completed',completed_at=now() WHERE id=a.id;
 UPDATE public.pallets SET state='staged',staging_address_id=staging WHERE warehouse_id=w AND id=p;
 SELECT shift,state INTO sh,current_presence FROM public.presence WHERE warehouse_id=w AND user_id=a.user_id AND ends_at IS NULL;
 UPDATE public.presence SET ends_at=now() WHERE warehouse_id=w AND user_id=a.user_id AND ends_at IS NULL;
 INSERT INTO public.presence(warehouse_id,user_id,state,shift) VALUES(w,a.user_id,CASE WHEN current_presence IN ('absent','break') THEN current_presence ELSE 'available' END,COALESCE(sh,'C'));
 INSERT INTO public.events(warehouse_id,actor_id,entity_type,entity_id,event_type,payload) VALUES(w,auth.uid(),'pallet',p,'staged',jsonb_build_object('staging',staging));
 -- Open issues remain visible to helper/checker; no global work lock.
END $$;
CREATE FUNCTION public.enqueue_integration(w uuid,adapter text,operation text,entity uuid,key text,payload jsonb) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result uuid; old_payload jsonb; old_entity uuid;
BEGIN
 IF NOT wms_private.manager(w) THEN RAISE EXCEPTION 'forbidden'; END IF;
 IF adapter='promax' AND operation NOT IN ('03.11.20.carga_montada','03.11.20.carregamento') THEN RAISE EXCEPTION 'unsupported Promax operation'; END IF;
 INSERT INTO public.integration_jobs(warehouse_id,adapter,operation,entity_id,idempotency_key,payload,state)
 VALUES(w,adapter,operation,entity,key,payload,'disabled') ON CONFLICT ON CONSTRAINT job_dedupe DO NOTHING RETURNING id INTO result;
 IF result IS NULL THEN
 SELECT id,j.payload,j.entity_id INTO result,old_payload,old_entity FROM public.integration_jobs j WHERE j.warehouse_id=w AND j.adapter=enqueue_integration.adapter AND j.operation=enqueue_integration.operation AND j.idempotency_key=key;
 IF old_payload<>payload OR old_entity<>entity THEN RAISE EXCEPTION 'idempotency payload conflict'; END IF;
 END IF;
 RETURN result;
END $$;
-- Agent-only claim contract; no Promax execution and no browser grants.
CREATE FUNCTION wms_private.claim_job(worker_adapter text) RETURNS public.integration_jobs LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j public.integration_jobs;
BEGIN
 IF worker_adapter='promax' THEN RAISE EXCEPTION 'Promax adapter disabled pending supervised implementation'; END IF;
 SELECT * INTO j FROM public.integration_jobs WHERE adapter=worker_adapter AND state IN ('queued','retry_wait') AND next_attempt_at<=now() AND attempts<max_attempts ORDER BY next_attempt_at LIMIT 1 FOR UPDATE SKIP LOCKED;
 IF j.id IS NULL THEN RETURN NULL; END IF;
 UPDATE public.integration_jobs SET state='running',attempts=attempts+1,lease_until=now()+interval '2 minutes',lease_token=gen_random_uuid() WHERE id=j.id RETURNING * INTO j;
 INSERT INTO public.integration_attempts(warehouse_id,job_id,attempt) VALUES(j.warehouse_id,j.id,j.attempts);
 RETURN j;
END $$;
REVOKE ALL ON FUNCTION wms_private.claim_job(text) FROM public,authenticated;
GRANT EXECUTE ON FUNCTION wms_private.claim_job(text) TO service_role;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public,anon;
GRANT EXECUTE ON FUNCTION public.set_presence(uuid,uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dispatch_next(uuid,uuid,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.report_issue(uuid,uuid,text,numeric,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_issue(uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_pallet(uuid,uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.enqueue_integration(uuid,text,text,uuid,text,jsonb) TO authenticated;
COMMIT;
