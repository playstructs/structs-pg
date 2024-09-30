-- Revert structs-pg:view-struct from pg

BEGIN;

DROP VIEW view.struct;

COMMIT;
