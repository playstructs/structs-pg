-- Revert structs-pg:function-generate-planet-name from pg

BEGIN;

DROP FUNCTION IF EXISTS structs.generate_planet_name(INTEGER);
DROP FUNCTION IF EXISTS structs.generate_planet_name();

COMMIT;
