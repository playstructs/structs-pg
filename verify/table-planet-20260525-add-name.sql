-- Verify structs-pg:table-planet-20260525-add-name on pg

BEGIN;

    SELECT name FROM structs.planet WHERE FALSE;

    DO $$
    BEGIN
        IF to_regclass('structs.planet_meta') IS NOT NULL THEN
            RAISE EXCEPTION 'expected structs.planet_meta to be dropped';
        END IF;

        IF EXISTS (
            SELECT 1
              FROM pg_attrdef d
              JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
              JOIN pg_class c ON c.oid = a.attrelid
              JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'structs'
               AND c.relname = 'planet'
               AND a.attname = 'name'
        ) THEN
            RAISE EXCEPTION 'expected structs.planet.name to have no column default';
        END IF;

        IF to_regprocedure('structs.generate_planet_name()') IS NULL THEN
            RAISE EXCEPTION 'expected structs.generate_planet_name() to exist';
        END IF;
    END
    $$;

ROLLBACK;
