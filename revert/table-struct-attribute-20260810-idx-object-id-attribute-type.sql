-- Revert structs-pg:table-struct-attribute-20260810-idx-object-id-attribute-type from pg

BEGIN;

    DROP INDEX IF EXISTS structs.struct_attribute_object_id_attribute_type_idx;

COMMIT;
