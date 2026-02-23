-- Deploy structs-pg:table-planet-20260221-add-seized-ore to pg

BEGIN;

    ALTER TABLE structs.planet_raid ADD COLUMN seized_ore NUMERIC;

COMMIT;
