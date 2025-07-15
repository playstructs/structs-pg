-- Revert structs-pg:table-stat from pg

BEGIN;

DROP TABLE IF EXISTS structs.stat_struct_status CASCADE;
DROP TABLE IF EXISTS structs.stat_struct_health CASCADE;
DROP TABLE IF EXISTS structs.stat_connection_capacity CASCADE;
DROP TABLE IF EXISTS structs.stat_connection_count CASCADE;
DROP TABLE IF EXISTS structs.stat_power CASCADE;
DROP TABLE IF EXISTS structs.stat_structs_load CASCADE;
DROP TABLE IF EXISTS structs.stat_load CASCADE;
DROP TABLE IF EXISTS structs.stat_capacity CASCADE;
DROP TABLE IF EXISTS structs.stat_fuel CASCADE;
DROP TABLE IF EXISTS structs.stat_ore CASCADE;
DROP TYPE IF EXISTS structs.object_type;
DROP FUNCTION IF EXISTS structs.GET_OBJECT_ID(object_type structs.object_type, index INTEGER);
DROP FUNCTION IF EXISTS structs.GET_OBJECT_TYPE(object_id INTEGER);

COMMIT;
