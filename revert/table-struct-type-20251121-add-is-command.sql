-- Revert structs-pg:table-struct-type-20251121-add-is-command from pg

BEGIN;

    ALTER TABLE structs.struct_type DROP COLUMN is_command;

COMMIT;
