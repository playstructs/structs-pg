-- Revert structs-pg:schema-sync-state-20260522 from pg

BEGIN;

    DROP SCHEMA IF EXISTS sync_state CASCADE;

COMMIT;
