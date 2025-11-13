-- Deploy structs-pg:table-struct-type-20251113-add-possible-ambit-array to pg

BEGIN;

    ALTER TABLE structs.struct_type ADD COLUMN possible_ambit_array jsonb GENERATED ALWAYS AS (structs.flag_to_ambits(possible_ambit)::jsonb) STORED;

COMMIT;
