-- Verify structs-pg:table-planet-attribute-20260914-idx-object-id-attribute-type on pg

BEGIN;

    DO $$
    BEGIN
        IF to_regclass('structs.planet_attribute_object_id_attribute_type_idx') IS NULL THEN
            RAISE EXCEPTION 'expected index structs.planet_attribute_object_id_attribute_type_idx';
        END IF;
    END
    $$;

ROLLBACK;
