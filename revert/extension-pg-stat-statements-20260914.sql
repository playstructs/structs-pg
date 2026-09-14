-- Revert structs-pg:extension-pg-stat-statements-20260914 from pg

BEGIN;

    DROP EXTENSION IF EXISTS pg_stat_statements;

COMMIT;
