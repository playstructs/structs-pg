-- Verify structs-pg:table-fleet-planet-20260909-idx-owner on pg

BEGIN;

    DO $$
    DECLARE
        def text;
    BEGIN
        IF to_regclass('structs.fleet_owner_idx') IS NULL THEN
            RAISE EXCEPTION 'expected structs.fleet_owner_idx to exist';
        END IF;

        SELECT pg_get_indexdef('structs.fleet_owner_idx'::regclass)
        INTO def;
        IF def NOT LIKE '%(owner)%' THEN
            RAISE EXCEPTION 'fleet_owner_idx columns unexpected: %', def;
        END IF;

        IF to_regclass('structs.planet_owner_idx') IS NULL THEN
            RAISE EXCEPTION 'expected structs.planet_owner_idx to exist';
        END IF;

        SELECT pg_get_indexdef('structs.planet_owner_idx'::regclass)
        INTO def;
        IF def NOT LIKE '%(owner)%' THEN
            RAISE EXCEPTION 'planet_owner_idx columns unexpected: %', def;
        END IF;
    END
    $$;

ROLLBACK;
