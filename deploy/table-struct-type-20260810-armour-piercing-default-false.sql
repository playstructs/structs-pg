-- Deploy structs-pg:table-struct-type-20260810-armour-piercing-default-false to pg
--
-- primary_weapon_armour_piercing / secondary_weapon_armour_piercing were added
-- as nullable booleans with no default. Align them with the other weapon
-- boolean flags by backfilling existing NULLs to false, then SET DEFAULT false
-- and SET NOT NULL.
--
-- Depends on cache-trigger-add-queue-20260810-armour-piercing-default-false so
-- the importer already coalesces missing chain fields to false before these
-- columns reject NULL.

BEGIN;

    UPDATE structs.struct_type
        SET primary_weapon_armour_piercing   = COALESCE(primary_weapon_armour_piercing, false),
            secondary_weapon_armour_piercing = COALESCE(secondary_weapon_armour_piercing, false)
        WHERE primary_weapon_armour_piercing IS NULL
           OR secondary_weapon_armour_piercing IS NULL;

    ALTER TABLE structs.struct_type
        ALTER COLUMN primary_weapon_armour_piercing   SET DEFAULT false,
        ALTER COLUMN primary_weapon_armour_piercing   SET NOT NULL,
        ALTER COLUMN secondary_weapon_armour_piercing SET DEFAULT false,
        ALTER COLUMN secondary_weapon_armour_piercing SET NOT NULL;

COMMIT;
