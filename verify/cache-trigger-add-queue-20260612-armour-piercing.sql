-- Verify structs-pg:cache-trigger-add-queue-20260612-armour-piercing on pg

BEGIN;

    SELECT 'cache.handle_event_struct_type(jsonb)'::regprocedure;

    DO $$
    DECLARE
        body text;
    BEGIN
        SELECT pg_get_functiondef('cache.handle_event_struct_type(jsonb)'::regprocedure)
        INTO body;
        IF body NOT LIKE '%primary_weapon_armour_piercing%'
           OR body NOT LIKE '%secondary_weapon_armour_piercing%'
           OR body NOT LIKE '%primaryWeaponArmourPiercing%'
           OR body NOT LIKE '%secondaryWeaponArmourPiercing%' THEN
            RAISE EXCEPTION 'handle_event_struct_type does not populate armour piercing columns';
        END IF;
    END
    $$;

ROLLBACK;
