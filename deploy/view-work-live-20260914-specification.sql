-- Deploy structs-pg:view-work-live-20260914-specification to pg
--
-- view.work_live is the specification of the work list: what can be hashed
-- on right now, by whom, against which target. It is computed from current
-- state on every read and is the source structs.api_work_refresh() diffs
-- from and structs.api_work_reconcile() checks against.
--
-- Two differences from view-work-20260914-filterable-unions:
--
-- 1. Structs with struct.is_destroyed are excluded from BUILD, MINE and
--    REFINE. The status bitmask (bit 32) is supposed to cover this, but on
--    production 8 destroyed structs had a status without that bit and were
--    being offered as BUILD work. is_destroyed is the authoritative flag.
--    The column is nullable, hence IS NOT TRUE.
-- 2. Clocks, shields and ore are looked up by (object_id, attribute_type)
--    instead of rebuilding the '<prefix>-<id>' text key with ||, so the
--    planner can use the (object_id, attribute_type) indexes on
--    struct_attribute, planet_attribute and grid and choose hash joins for
--    full scans. Prefix to attribute_type mapping, from production data:
--
--   struct_attribute  1 status, 2 blockStartBuild
--   planet_attribute  0 planetaryShield, 10 blockStartRaid,
--                     12 blockStartOreMine, 13 blockStartOreRefine
--   grid              0 ore
--
-- view.work becomes SELECT * FROM view.work_live so today's readers get the
-- cheaper plan. A later change re-points view.work at structs.api_work once
-- sync-state calls api_work_refresh() every block.

BEGIN;

    CREATE VIEW view.work_live AS
        SELECT
            struct.id AS object_id,
            struct.owner AS player_id,
            struct.id AS target_id,
            'BUILD'::text AS category,
            COALESCE(build_clock.val, 0) AS block_start,
            struct_type.build_difficulty AS difficulty_target,
            struct.location_type,
            struct.location_id,
            CASE WHEN struct.location_type = 'planet' THEN struct.location_id ELSE NULL END AS planet_id
        FROM structs.struct
            INNER JOIN structs.struct_attribute status
                ON status.object_id = struct.id AND status.attribute_type = 'status'
            INNER JOIN structs.struct_type ON struct_type.id = struct.type
            LEFT JOIN structs.struct_attribute build_clock
                ON build_clock.object_id = struct.id AND build_clock.attribute_type = 'blockStartBuild'
        WHERE (status.val & 34) = 0 -- not built, not destroyed
            AND struct.is_destroyed IS NOT TRUE

        UNION ALL

        SELECT
            struct.id AS object_id,
            struct.owner AS player_id,
            struct.id AS target_id,
            'MINE'::text AS category,
            COALESCE(mine_clock.val, 0) AS block_start,
            struct_type.ore_mining_difficulty AS difficulty_target,
            struct.location_type,
            struct.location_id,
            CASE WHEN struct.location_type = 'planet' THEN struct.location_id ELSE NULL END AS planet_id
        FROM structs.struct
            INNER JOIN structs.struct_attribute status
                ON status.object_id = struct.id AND status.attribute_type = 'status'
            INNER JOIN structs.struct_type ON struct_type.id = struct.type
            LEFT JOIN structs.planet_attribute mine_clock
                ON mine_clock.object_id = struct.location_id AND mine_clock.attribute_type = 'blockStartOreMine'
        WHERE (status.val & 4) > 0 -- online
            AND struct.is_destroyed IS NOT TRUE
            AND struct_type.planetary_mining = 'oreMiningRig'
            AND EXISTS (
                SELECT FROM structs.grid planet_ore
                WHERE planet_ore.object_id = struct.location_id
                  AND planet_ore.attribute_type = 'ore'
                  AND planet_ore.val > 0
            )

        UNION ALL

        SELECT
            struct.id AS object_id,
            struct.owner AS player_id,
            struct.id AS target_id,
            'REFINE'::text AS category,
            COALESCE(refine_clock.val, 0) AS block_start,
            struct_type.ore_refining_difficulty AS difficulty_target,
            struct.location_type,
            struct.location_id,
            CASE WHEN struct.location_type = 'planet' THEN struct.location_id ELSE NULL END AS planet_id
        FROM structs.struct
            INNER JOIN structs.struct_attribute status
                ON status.object_id = struct.id AND status.attribute_type = 'status'
            INNER JOIN structs.struct_type ON struct_type.id = struct.type
            LEFT JOIN structs.planet_attribute refine_clock
                ON refine_clock.object_id = struct.location_id AND refine_clock.attribute_type = 'blockStartOreRefine'
        WHERE (status.val & 4) > 0 -- online
            AND struct.is_destroyed IS NOT TRUE
            AND struct_type.planetary_refinery = 'oreRefinery'
            AND EXISTS (
                SELECT FROM structs.grid player_ore
                WHERE player_ore.object_id = struct.owner
                  AND player_ore.attribute_type = 'ore'
                  AND player_ore.val > 0
            )

        UNION ALL

        SELECT
            planet.location_list_start AS object_id,
            fleet.owner AS player_id,
            planet.id AS target_id,
            'RAID'::text AS category,
            COALESCE(raid_clock.val, 0) AS block_start,
            COALESCE(shield.val, 0) AS difficulty_target,
            'planet'::character varying AS location_type,
            planet.id AS location_id,
            planet.id AS planet_id
        FROM structs.planet
            LEFT JOIN structs.fleet
                ON fleet.id = planet.location_list_start
            LEFT JOIN structs.planet_attribute raid_clock
                ON raid_clock.object_id = planet.id AND raid_clock.attribute_type = 'blockStartRaid'
            LEFT JOIN structs.planet_attribute shield
                ON shield.object_id = planet.id AND shield.attribute_type = 'planetaryShield'
        WHERE planet.location_list_start <> '';

    COMMENT ON VIEW view.work_live IS
        'Specification of the work list (BUILD/MINE/REFINE/RAID), computed from current state on every read. Source for structs.api_work_refresh(); compared against structs.api_work by structs.api_work_reconcile(). Do not read on request paths.';

    CREATE OR REPLACE VIEW view.work AS
        SELECT object_id, player_id, target_id, category, block_start,
               difficulty_target, location_type, location_id, planet_id
        FROM view.work_live;

COMMIT;
