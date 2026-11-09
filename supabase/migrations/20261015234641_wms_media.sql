BEGIN;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('wms-evidence','wms-evidence',false,52428800,ARRAY['image/jpeg','image/png','image/webp','video/mp4']) ON CONFLICT(id) DO NOTHING;
CREATE POLICY wms_evidence_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='wms-evidence' AND EXISTS(SELECT 1 FROM public.media_records m WHERE m.object_path=name AND wms_private.member(m.warehouse_id)));
CREATE POLICY wms_evidence_upload ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='wms-evidence' AND EXISTS(SELECT 1 FROM public.media_records m WHERE m.object_path=name AND m.uploaded_by=auth.uid() AND m.state IN ('pending','failed') AND wms_private.member(m.warehouse_id)));
-- Objects are append-only. No client UPDATE/DELETE; corrections create another record.
COMMIT;
