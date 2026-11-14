-- Verify structs-pg:grid-cap-handler-permissions-20261114 on pg
BEGIN;
DO $$ BEGIN
    -- Check grants rather than superuser bypass: some existing installations
    -- provision structs_webapp as a superuser independently of this migration.
    IF EXISTS (SELECT 1 FROM pg_proc p,
           LATERAL aclexplode(COALESCE(p.proacl, acldefault('f',p.proowner))) a
           WHERE p.oid='cache.handle_event_grid(jsonb)'::regprocedure
             AND a.grantee IN (0, 'structs_webapp'::regrole::oid) AND a.privilege_type='EXECUTE') THEN
        RAISE EXCEPTION 'grid compatibility handler is executable by an untrusted role';
    END IF;
END $$;
ROLLBACK;
