-- Verify structs-pg:function-api-work-20260914-refresh on pg
--
-- Runs the refresh twice inside a transaction that is rolled back: the first
-- call must populate api_work from view.work_live, the second must be a
-- no-op. Nothing persists.

BEGIN;

    DO $$
    DECLARE
        r1 record;
        r2 record;
        live_count bigint;
        api_count  bigint;
    BEGIN
        IF to_regprocedure('structs.api_work_refresh(bigint, timestamptz)') IS NULL THEN
            RAISE EXCEPTION 'expected function structs.api_work_refresh(bigint, timestamptz)';
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM pg_proc p
              CROSS JOIN LATERAL aclexplode(p.proacl) acl
             WHERE p.oid = 'structs.api_work_refresh(bigint, timestamptz)'::regprocedure
               AND acl.grantee = 'structs_indexer'::regrole
               AND acl.privilege_type = 'EXECUTE'
        ) THEN
            RAISE EXCEPTION 'structs_indexer lacks EXECUTE on structs.api_work_refresh';
        END IF;

        SELECT * INTO r1 FROM structs.api_work_refresh(0, now());
        SELECT count(*) INTO live_count FROM view.work_live;
        SELECT count(*) INTO api_count  FROM structs.api_work;
        IF api_count <> live_count THEN
            RAISE EXCEPTION 'api_work_refresh left % rows, view.work_live has %',
                api_count, live_count;
        END IF;

        SELECT * INTO r2 FROM structs.api_work_refresh(0, now());
        IF r2.inserted <> 0 OR r2.updated <> 0 OR r2.deleted <> 0 THEN
            RAISE EXCEPTION 'api_work_refresh is not idempotent: second call returned %', r2;
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM structs.api_refresh_state WHERE model = 'work' AND source_height = 0
        ) THEN
            RAISE EXCEPTION 'api_work_refresh did not record model work in api_refresh_state';
        END IF;
    END
    $$;

ROLLBACK;
