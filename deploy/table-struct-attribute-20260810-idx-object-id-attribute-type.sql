-- Deploy structs-pg:table-struct-attribute-20260810-idx-object-id-attribute-type to pg
--
-- Both StructManager hot paths join struct_attribute twice (health and status)
-- on (object_id, attribute_type). val is the churned column and is not in this
-- index, so HOT updates stay available.

BEGIN;

    CREATE INDEX struct_attribute_object_id_attribute_type_idx
        ON structs.struct_attribute (object_id, attribute_type);

COMMIT;
