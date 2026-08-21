-- Verify structs-pg:table-struct-type-20260820-add-can-defend on pg

BEGIN;

    DO $$
    DECLARE
        nullable text;
        default_value text;
    BEGIN
        SELECT is_nullable, column_default
          INTO nullable, default_value
          FROM information_schema.columns
         WHERE table_schema = 'structs'
           AND table_name = 'struct_type'
           AND column_name = 'can_defend';

        IF nullable IS NULL THEN
            RAISE EXCEPTION 'expected structs.struct_type.can_defend to exist';
        END IF;

        IF nullable <> 'NO' OR default_value <> 'false' THEN
            RAISE EXCEPTION
                'can_defend expected NOT NULL DEFAULT false, got is_nullable=% column_default=%',
                nullable, default_value;
        END IF;
    END
    $$;

ROLLBACK;
