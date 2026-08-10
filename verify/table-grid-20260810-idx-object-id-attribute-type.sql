-- Verify structs-pg:table-grid-20260810-idx-object-id-attribute-type on pg

BEGIN;

    DO $$
    DECLARE
        def text;
    BEGIN
        IF to_regclass('structs.grid_object_id_attribute_type_idx') IS NULL THEN
            RAISE EXCEPTION 'expected structs.grid_object_id_attribute_type_idx to exist';
        END IF;

        SELECT pg_get_indexdef('structs.grid_object_id_attribute_type_idx'::regclass)
        INTO def;

        IF def NOT LIKE '%(object_id, attribute_type)%' THEN
            RAISE EXCEPTION 'grid_object_id_attribute_type_idx columns unexpected: %', def;
        END IF;
    END
    $$;

ROLLBACK;
