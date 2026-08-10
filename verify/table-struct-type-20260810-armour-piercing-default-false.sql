-- Verify structs-pg:table-struct-type-20260810-armour-piercing-default-false on pg

BEGIN;

    DO $$
    DECLARE
        r record;
    BEGIN
        FOR r IN
            SELECT column_name, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'structs'
              AND table_name = 'struct_type'
              AND column_name IN (
                  'primary_weapon_armour_piercing',
                  'secondary_weapon_armour_piercing'
              )
        LOOP
            IF r.is_nullable <> 'NO' OR r.column_default <> 'false' THEN
                RAISE EXCEPTION
                    'column % expected NOT NULL DEFAULT false, got is_nullable=% column_default=%',
                    r.column_name, r.is_nullable, r.column_default;
            END IF;
        END LOOP;
    END
    $$;

ROLLBACK;
