-- Revert structs-pg:table-struct-type-20260615-cheatsheet-armour-battleship-secondary from pg
--
-- Restores the cheatsheet cells to their prior (empty) state and re-syncs the
-- affected struct_type rows.

BEGIN;

    UPDATE structs.struct_type_cs
       SET secondary_weapon_label = '',
           secondary_weapon_class = ''
     WHERE class = 'Battleship' AND language = 'EN';

    UPDATE structs.struct_type_cs
       SET unit_defenses_label       = '',
           unit_defenses_description = ''
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
