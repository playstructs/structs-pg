-- Revert structs-pg:table-struct from pg

BEGIN;

DROP FUNCTION IF EXISTS structs.GET_ACTIVITY_LOCATION_ID(_struct_id CHARACTER VARYING);
DROP TABLE IF EXISTS structs.struct_defender CASCADE;
DROP TABLE IF EXISTS structs.struct_attribute CASCADE;
DROP TABLE IF EXISTS structs.struct CASCADE;

COMMIT;
