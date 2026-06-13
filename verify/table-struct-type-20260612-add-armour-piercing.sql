-- Verify structs-pg:table-struct-type-20260612-add-armour-piercing on pg

BEGIN;

    SELECT primary_weapon_armour_piercing, secondary_weapon_armour_piercing
        FROM structs.struct_type WHERE FALSE;

    SELECT primary_weapon_armour_piercing, secondary_weapon_armour_piercing
        FROM view.struct WHERE FALSE;

ROLLBACK;
