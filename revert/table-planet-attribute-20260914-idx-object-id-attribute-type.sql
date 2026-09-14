-- Revert structs-pg:table-planet-attribute-20260914-idx-object-id-attribute-type from pg

BEGIN;

    DROP INDEX IF EXISTS structs.planet_attribute_object_id_attribute_type_idx;

COMMIT;
