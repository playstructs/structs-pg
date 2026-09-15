-- Revert structs-pg:index-catalog-20260915-updated-at-id from pg

BEGIN;

    DROP INDEX IF EXISTS structs.struct_updated_at_id_idx;
    DROP INDEX IF EXISTS structs.struct_attribute_updated_at_id_idx;
    DROP INDEX IF EXISTS structs.planet_attribute_updated_at_id_idx;
    DROP INDEX IF EXISTS structs.planet_attribute_attribute_type_updated_at_id_idx;
    DROP INDEX IF EXISTS structs.grid_updated_at_id_idx;
    DROP INDEX IF EXISTS structs.grid_attribute_object_updated_at_id_idx;
    DROP INDEX IF EXISTS structs.planet_updated_at_id_idx;

COMMIT;
