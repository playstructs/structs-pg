-- Revert structs-pg:table-api-work-20260914-current-state from pg

BEGIN;

    DROP TABLE IF EXISTS structs.api_work;

COMMIT;
