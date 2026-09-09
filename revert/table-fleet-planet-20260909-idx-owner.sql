-- Revert structs-pg:table-fleet-planet-20260909-idx-owner from pg

BEGIN;

    DROP INDEX IF EXISTS structs.planet_owner_idx;
    DROP INDEX IF EXISTS structs.fleet_owner_idx;

COMMIT;
