-- Revert structs-pg:table-planet from pg

BEGIN;

    ALTER TABLE structs.planet_raid DROP COLUMN seized_ore;

COMMIT;
