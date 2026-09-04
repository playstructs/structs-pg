-- Revert structs-pg:table-attribute-type-20260904-not-null from pg

BEGIN;

    ALTER TABLE structs.planet_attribute
        ALTER COLUMN attribute_type DROP NOT NULL;

    ALTER TABLE structs.struct_attribute
        ALTER COLUMN attribute_type DROP NOT NULL;

    ALTER TABLE structs.grid
        ALTER COLUMN attribute_type DROP NOT NULL;

COMMIT;
