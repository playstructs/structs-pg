-- Deploy structs-pg:table-allocation-20260325-drop-locked to pg

BEGIN;

    ALTER TABLE structs.allocation DROP COLUMN IF EXISTS locked;

COMMIT;
