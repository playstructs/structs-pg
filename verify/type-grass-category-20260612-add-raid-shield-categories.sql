-- Verify structs-pg:type-grass-category-20260612-add-raid-shield-categories on pg

BEGIN;

    SELECT 'shield_change'::structs.grass_category;
    SELECT 'block_raid_start'::structs.grass_category;

ROLLBACK;
