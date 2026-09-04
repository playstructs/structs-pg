-- Verify structs-pg:table-attribute-type-20260904-not-null on pg

BEGIN;

    DO $$
    DECLARE
        is_nullable text;
    BEGIN
        SELECT c.is_nullable INTO is_nullable
          FROM information_schema.columns c
         WHERE c.table_schema = 'structs'
           AND c.table_name = 'planet_attribute'
           AND c.column_name = 'attribute_type';
        IF is_nullable IS DISTINCT FROM 'NO' THEN
            RAISE EXCEPTION 'planet_attribute.attribute_type should be NOT NULL';
        END IF;

        SELECT c.is_nullable INTO is_nullable
          FROM information_schema.columns c
         WHERE c.table_schema = 'structs'
           AND c.table_name = 'struct_attribute'
           AND c.column_name = 'attribute_type';
        IF is_nullable IS DISTINCT FROM 'NO' THEN
            RAISE EXCEPTION 'struct_attribute.attribute_type should be NOT NULL';
        END IF;

        SELECT c.is_nullable INTO is_nullable
          FROM information_schema.columns c
         WHERE c.table_schema = 'structs'
           AND c.table_name = 'grid'
           AND c.column_name = 'attribute_type';
        IF is_nullable IS DISTINCT FROM 'NO' THEN
            RAISE EXCEPTION 'grid.attribute_type should be NOT NULL';
        END IF;
    END
    $$;

ROLLBACK;
