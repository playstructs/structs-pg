-- Deploy structs-pg:type-grass-category-20260612-add-raid-shield-categories to pg
--
-- structsd v0.18.0 ("New Raid State - Shields Vulnerable" + planetary shield
-- tracking) introduces two new planet_activity categories:
--
--   shield_change     a planet's shield value changed; detail carries
--                     {planetary_shield, planetary_shield_old}
--   block_raid_start  the block height at which a raid began
--
-- planet_activity.category is structs.grass_category and detail is schema-less
-- jsonb, so only the enum values are needed here; sync-state emits the rows.
--
-- Both values are positioned AFTER 'struct_health' (an already-committed
-- label) on purpose: a value added by ALTER TYPE ... ADD VALUE cannot be
-- referenced (including as an AFTER anchor) within the same transaction that
-- adds it, so the second statement does not anchor on 'shield_change'.

BEGIN;

    ALTER TYPE structs.grass_category ADD VALUE 'shield_change'    AFTER 'struct_health';
    ALTER TYPE structs.grass_category ADD VALUE 'block_raid_start' AFTER 'struct_health';

COMMIT;
