-- Revert structs-pg:function-api-work-20260914-refresh from pg

BEGIN;

    DROP FUNCTION IF EXISTS structs.api_work_refresh(BIGINT, TIMESTAMPTZ);

COMMIT;
