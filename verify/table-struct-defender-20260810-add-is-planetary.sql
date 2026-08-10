-- Verify structs-pg:table-struct-defender-20260810-add-is-planetary on pg

BEGIN;

    DO $$
    DECLARE
        r record;
    BEGIN
        SELECT is_nullable, column_default
        INTO r
        FROM information_schema.columns
        WHERE table_schema = 'structs'
          AND table_name = 'struct_defender'
          AND column_name = 'is_planetary';

        IF NOT FOUND THEN
            RAISE EXCEPTION 'expected structs.struct_defender.is_planetary to exist';
        END IF;

        IF r.is_nullable <> 'NO' OR r.column_default <> 'false' THEN
            RAISE EXCEPTION
                'is_planetary expected NOT NULL DEFAULT false, got is_nullable=% column_default=%',
                r.is_nullable, r.column_default;
        END IF;
    END
    $$;

ROLLBACK;
