BEGIN;
DO $migration$
DECLARE f record; signature text; call_args text;
BEGIN
 FOR f IN SELECT p.oid,p.proname,pg_get_function_identity_arguments(p.oid) AS identity_args,pg_get_function_arguments(p.oid) AS args,pg_get_function_result(p.oid) AS result,p.pronargs FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef LOOP
 signature:=format('%I.%I(%s)','public',f.proname,f.identity_args);
 EXECUTE 'ALTER FUNCTION '||signature||' SET SCHEMA wms_private';
 SELECT string_agg('$'||i,',') INTO call_args FROM generate_series(1,f.pronargs) i;
 EXECUTE format('CREATE FUNCTION public.%I(%s) RETURNS %s LANGUAGE sql SECURITY INVOKER SET search_path='''' AS %L',f.proname,f.args,f.result,format('SELECT wms_private.%I(%s)',f.proname,call_args));
 EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM public,anon',f.proname,f.identity_args);
 EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO authenticated',f.proname,f.identity_args);
 END LOOP;
END $migration$;
-- Cover all foreign key lookups, without duplicating existing leading-key indexes.
DO $indexes$
DECLARE fk record; cols text;
BEGIN
 FOR fk IN SELECT c.oid,c.conrelid,c.conkey,n.nspname,t.relname FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace WHERE c.contype='f' AND n.nspname='public' AND NOT EXISTS(SELECT 1 FROM pg_index i WHERE i.indrelid=c.conrelid AND i.indisvalid AND (i.indkey::smallint[])[0:array_length(c.conkey,1)-1] @> c.conkey) LOOP
 SELECT string_agg(quote_ident(a.attname),',' ORDER BY k.ord) INTO cols FROM unnest(fk.conkey) WITH ORDINALITY k(attnum,ord) JOIN pg_attribute a ON a.attrelid=fk.conrelid AND a.attnum=k.attnum;
 EXECUTE format('CREATE INDEX %I ON %I.%I(%s)','wms_fk_'||fk.oid,fk.nspname,fk.relname,cols);
 END LOOP;
END $indexes$;
COMMIT;
