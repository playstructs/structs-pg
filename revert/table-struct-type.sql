-- Revert structs-pg:table-struct-type from pg

BEGIN;

DROP TABLE IF EXISTS structs.struct_type_meta CASCADE;
DROP TABLE IF EXISTS struct_type CASCADE;

COMMIT;
