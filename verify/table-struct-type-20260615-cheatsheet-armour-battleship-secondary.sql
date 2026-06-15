-- Verify structs-pg:table-struct-type-20260615-cheatsheet-armour-battleship-secondary on pg

BEGIN;

    DO $$
    BEGIN
        ASSERT (SELECT secondary_weapon_label = 'Plasma Missile'
                       AND secondary_weapon_class = 'Smart Weapon'
                FROM structs.struct_type_cs
                WHERE class = 'Battleship' AND language = 'EN'),
            'struct_type_cs Battleship secondary weapon not set';

        ASSERT (SELECT bool_and(unit_defenses_label = 'Ablative Armour'
                                AND unit_defenses_description = 'Reduces all incoming DMG to 1.')
                FROM structs.struct_type_cs
                WHERE class IN ('Field Generator','Continental Power Plant','World Engine')
                  AND language = 'EN'),
            'struct_type_cs power-struct armour text not set';

        ASSERT (SELECT secondary_weapon_label = 'Plasma Missile'
                       AND secondary_weapon_class = 'Smart Weapon'
                FROM structs.struct_type
                WHERE class = 'Battleship'),
            'struct_type Battleship secondary weapon not synced';

        ASSERT (SELECT bool_and(unit_defenses_label = 'Ablative Armour'
                                AND unit_defenses_description = 'Reduces all incoming DMG to 1.')
                FROM structs.struct_type
                WHERE class IN ('Field Generator','Continental Power Plant','World Engine')),
            'struct_type power-struct armour text not synced';
    END
    $$;

ROLLBACK;
