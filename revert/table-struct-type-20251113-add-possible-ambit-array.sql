-- Revert structs-pg:table-struct-type-20251113-add-possible-ambit-array from pg

BEGIN;

    ALTER TABLE structs.struct_type DROP COLUMN possible_ambit_array;

COMMIT;
