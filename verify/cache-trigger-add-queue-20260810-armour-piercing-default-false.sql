-- Verify structs-pg:cache-trigger-add-queue-20260810-armour-piercing-default-false on pg

BEGIN;

    SELECT 'cache.handle_event_struct_type(jsonb)'::regprocedure;

    DO $$
    DECLARE
        body text;
    BEGIN
        SELECT pg_get_functiondef('cache.handle_event_struct_type(jsonb)'::regprocedure)
        INTO body;
        IF body NOT LIKE '%COALESCE(x."primaryWeaponArmourPiercing", false)%'
           OR body NOT LIKE '%COALESCE(x."secondaryWeaponArmourPiercing", false)%' THEN
            RAISE EXCEPTION 'handle_event_struct_type does not coalesce armour piercing to false';
        END IF;
    END
    $$;

ROLLBACK;
