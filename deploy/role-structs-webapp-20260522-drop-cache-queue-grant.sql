-- Deploy structs-pg:role-structs-webapp-20260522-drop-cache-queue-grant to pg
--
-- Removes the orphan cache.queue grant from structs_webapp. cache.queue
-- had no producer in the cache.* event-handler stack — no live consumer
-- was identified during the cache-retirement audit. The subsequent
-- retire-cache-20260522 change drops cache.queue along with the rest of
-- the cache schema (no compatibility view); removing the grant up front
-- means re-applying role-structs-webapp.sql against a post-cutover DB
-- cannot fail with "relation cache.queue does not exist".
--
-- EXISTS-guarded so the change is idempotent against:
--   - fresh sqitch deploys (cache.queue exists from cache-system.sql)
--   - live cutover (sync-state's operator script REVOKEd defensively
--     before DROP SCHEMA CASCADE, but cache.queue still exists at this
--     point in deploy order)
--   - already-cutover environments (cache.queue gone, REVOKE skipped)

BEGIN;

    DO $$
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'structs_webapp')
           AND EXISTS (SELECT 1 FROM information_schema.tables
                        WHERE table_schema = 'cache' AND table_name = 'queue') THEN
            REVOKE SELECT, DELETE ON cache.queue FROM structs_webapp;
        END IF;
    END $$;

COMMIT;
