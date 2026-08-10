-- Revert structs-pg:table-grid-20260810-idx-object-id-attribute-type from pg

BEGIN;

    DROP INDEX IF EXISTS structs.grid_object_id_attribute_type_idx;

COMMIT;
