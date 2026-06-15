-- Deploy structs-pg:table-struct-type-20260615-cheatsheet-armour-battleship-secondary to pg
--
-- Fills two gaps where struct_type_cs cheatsheet text trailed the functional
-- balance columns:
--   * Field Generator / Continental Power Plant / World Engine functionally
--     carry unit_defenses='armour' (attack_reduction=1), identical to the Tank,
--     but had no unit-defense label/description. Reuse the Tank's wording.
--   * The Battleship functionally carries secondary_weapon='guidedWeaponry'
--     (guided -> Smart Weapon) but had no secondary-weapon label/class.
--
-- The STRUCT_TYPE_SYNC_CS trigger only fires on struct_type writes, so after
-- editing struct_type_cs we explicitly burn the new values into struct_type.

BEGIN;

    UPDATE structs.struct_type_cs
       SET secondary_weapon_label = 'Plasma Missile',
           secondary_weapon_class = 'Smart Weapon'
     WHERE class = 'Battleship' AND language = 'EN';

    UPDATE structs.struct_type_cs
       SET unit_defenses_label       = 'Ablative Armour',
           unit_defenses_description = 'Reduces all incoming DMG to 1.'
     WHERE class IN ('Field Generator','Continental Power Plant','World Engine')
       AND language = 'EN';

    UPDATE structs.struct_type SET
        secondary_weapon_label    = cs.secondary_weapon_label,
        secondary_weapon_class    = cs.secondary_weapon_class,
        unit_defenses_label       = cs.unit_defenses_label,
        unit_defenses_description = cs.unit_defenses_description
    FROM structs.struct_type_cs cs
    WHERE cs.class = struct_type.class
      AND cs.language = 'EN'
      AND struct_type.class IN ('Battleship','Field Generator','Continental Power Plant','World Engine');

COMMIT;
