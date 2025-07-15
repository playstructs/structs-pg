-- Revert structs-pg:view-struct from pg

BEGIN;

DROP VIEW IF EXISTS view.struct_status CASCADE;
DROP VIEW IF EXISTS view.struct CASCADE;

COMMIT;
