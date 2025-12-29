-- Deploy structs-pg:table-struct-20251229-add-destroyed to pg

BEGIN;

    ALTER TABLE structs.struct ADD COLUMN is_destroyed BOOLEAN DEFAULT 'f';

    UPDATE structs.struct SET is_destroyed = 't' WHERE EXISTS (SELECT FROM view.struct_status WHERE struct_status.struct_id = struct.id AND struct_status.destroyed);

COMMIT;
