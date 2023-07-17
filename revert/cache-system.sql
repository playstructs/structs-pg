-- Revert structs-pg:cache-system from pg

BEGIN;

DROP SCHEMA cache CASCADE;

COMMIT;
