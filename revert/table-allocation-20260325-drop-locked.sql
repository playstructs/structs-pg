-- Revert structs-pg:table-allocation-20260325-drop-locked from pg

BEGIN;

    ALTER TABLE structs.allocation ADD COLUMN locked BOOLEAN;

COMMIT;
