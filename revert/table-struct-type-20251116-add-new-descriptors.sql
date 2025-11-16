-- Revert structs-pg:table-struct-type-20251116-add-new-descriptors from pg

BEGIN;

    ALTER TABLE structs.struct_type DROP COLUMN IF EXISTS default_cosmetic_name;
    ALTER TABLE structs.struct_type DROP COLUMN IF EXISTS default_cosmetic_model_number;
    ALTER TABLE structs.struct_type DROP COLUMN IF EXISTS class_abbreviation;
    ALTER TABLE structs.struct_type DROP COLUMN IF EXISTS class;

COMMIT;
