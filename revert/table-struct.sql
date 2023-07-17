-- Revert structs-pg:table-struct from pg

BEGIN;

DROP TABLE structs.struct;

COMMIT;
