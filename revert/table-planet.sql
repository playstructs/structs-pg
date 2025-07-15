-- Revert structs-pg:table-planet from pg

BEGIN;

DROP TABLE IF EXISTS structs.planet_activity CASCADE;
DROP TABLE IF EXISTS structs.planet_activity_sequence CASCADE;
DROP TABLE IF EXISTS structs.planet_raid CASCADE;
DROP TABLE IF EXISTS structs.planet_attribute CASCADE;
DROP TABLE IF EXISTS structs.planet_meta CASCADE;
DROP TABLE IF EXISTS structs.planet CASCADE;
DROP FUNCTION IF EXISTS structs.GET_PLANET_ACTIVITY_SEQUENCE(character varying);

COMMIT;
