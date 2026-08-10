-- Revert structs-pg:table-struct-type-20260810-armour-piercing-default-false from pg
--
-- Drops NOT NULL and DEFAULT on both armour-piercing columns. Backfilled false
-- values from the deploy UPDATE are left as-is (not restored to NULL).

BEGIN;

    ALTER TABLE structs.struct_type
        ALTER COLUMN primary_weapon_armour_piercing   DROP NOT NULL,
        ALTER COLUMN primary_weapon_armour_piercing   DROP DEFAULT,
        ALTER COLUMN secondary_weapon_armour_piercing DROP NOT NULL,
        ALTER COLUMN secondary_weapon_armour_piercing DROP DEFAULT;

COMMIT;
