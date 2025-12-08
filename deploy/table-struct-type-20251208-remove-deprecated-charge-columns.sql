-- Deploy structs-pg:table-struct-type-20251208-remove-deprecated-charge-columns to pg

BEGIN;

    DROP VIEW IF EXISTS view.struct;

    ALTER TABLE structs.struct_type DROP COLUMN IF EXISTS ore_mining_charge;
    ALTER TABLE structs.struct_type DROP COLUMN IF EXISTS ore_refining_charge;

COMMIT;
