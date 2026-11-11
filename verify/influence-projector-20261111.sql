BEGIN;
SELECT source FROM structs.influence_raid WHERE false;
SELECT event_time FROM structs.influence_membership_history WHERE false;
SELECT 1/(to_regprocedure('structs.influence_begin_block(text,bigint,text,timestamptz,boolean)') IS NOT NULL)::int;
SELECT 1/(to_regprocedure('structs.influence_rebuild(bigint)') IS NOT NULL)::int;
SELECT 1/(to_regprocedure('structs.influence_rewind(text,bigint,text)') IS NOT NULL)::int;
SELECT * FROM structs.influence_reconcile(-1);
-- Check declared ACLs separately from role configuration: legacy installations
-- make application roles superusers, which bypass every object ACL.
SELECT 1/(count(*)=0)::int FROM pg_class c CROSS JOIN LATERAL aclexplode(c.relacl) a
 WHERE c.oid IN ('structs.influence_raid'::regclass,'structs.influence_membership_history'::regclass)
 AND a.grantee=(SELECT oid FROM pg_roles WHERE rolname='structs_indexer') AND a.privilege_type IN ('UPDATE','DELETE');
SELECT 1/(count(*)=0)::int FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
 WHERE p.oid='structs.influence_create_contest(text,bigint,bigint,bigint)'::regprocedure
 AND a.grantee=(SELECT oid FROM pg_roles WHERE rolname='structs_webapp');
DO $$ BEGIN IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname IN ('structs_indexer','structs_webapp') AND rolsuper)
 THEN RAISE WARNING 'Application roles are superusers: influence ACLs require non-superuser deployment roles to be enforceable'; END IF; END $$;
SELECT 1/(count(*)=0)::int FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace,
 LATERAL aclexplode(p.proacl) a WHERE n.nspname='structs' AND p.proname='influence_create_contest' AND a.grantee=0;
ROLLBACK;
