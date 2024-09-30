-- Revert structs-pg:table-struct from pg

BEGIN;

DROP TABLE structs.struct;

DROP TABLE structs.struct_attack;
DROP TABLE structs.struct_attribute;
DROP TABLE structs.struct_defender;

COMMIT;
