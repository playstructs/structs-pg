-- Deploy structs-pg:table-struct-type-20251121-add-is-command to pg

BEGIN;

    ALTER TABLE structs.struct_type ADD COLUMN is_command BOOLEAN DEFAULT 'false';
    UPDATE structs.struct_type SET is_command = 'true' where class = 'Command Ship';

COMMIT;
