-- Revert structs-pg:role-structs-webapp-20260522-drop-cache-queue-grant from pg
--
-- Restores the original cache.queue grant from role-structs-webapp.sql:13.
-- Only meaningful if reverting back past retire-cache-20260522 (which
-- would otherwise have dropped cache.queue entirely); EXISTS-guarded so
-- a partial revert against a post-cutover DB is a no-op.

BEGIN;

    DO $$
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'structs_webapp')
           AND EXISTS (SELECT 1 FROM information_schema.tables
                        WHERE table_schema = 'cache' AND table_name = 'queue') THEN
            GRANT SELECT, DELETE ON cache.queue TO structs_webapp;
        END IF;
    END $$;

COMMIT;
