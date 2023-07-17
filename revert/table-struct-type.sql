-- Revert structs-pg:table-struct-type from pg

BEGIN;

DROP TABLE structs.struct_type;

COMMIT;
