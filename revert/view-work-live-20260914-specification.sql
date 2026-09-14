-- Revert structs-pg:view-work-live-20260914-specification from pg
--
-- Restore view.work to its view-work-20260914-filterable-unions definition
-- and drop the specification view.

BEGIN;

    CREATE OR REPLACE VIEW view.work AS
        SELECT
            sa.object_id AS object_id,
            struct.owner AS player_id,
            sa.object_id AS target_id,
            'BUILD'::text AS category,
            COALESCE(build_clock.val, 0) AS block_start,
            struct_type.build_difficulty AS difficulty_target,
            struct.location_type,
            struct.location_id,
            CASE WHEN struct.location_type = 'planet' THEN struct.location_id ELSE NULL END AS planet_id
        FROM structs.struct
            INNER JOIN structs.struct_attribute sa
                ON sa.object_id = struct.id AND sa.attribute_type = 'status'
            INNER JOIN structs.struct_type ON struct.type = struct_type.id
            LEFT JOIN structs.struct_attribute build_clock
                ON build_clock.id = '2-' || struct.id
        WHERE (sa.val & 34) = 0 -- not built, not destroyed

        UNION ALL

        SELECT
            sa.object_id AS object_id,
            struct.owner AS player_id,
            sa.object_id AS target_id,
            'MINE'::text AS category,
            COALESCE(mine_clock.val, 0) AS block_start,
            struct_type.ore_mining_difficulty AS difficulty_target,
            struct.location_type,
            struct.location_id,
            CASE WHEN struct.location_type = 'planet' THEN struct.location_id ELSE NULL END AS planet_id
        FROM structs.struct
            INNER JOIN structs.struct_attribute sa
                ON sa.object_id = struct.id AND sa.attribute_type = 'status'
            INNER JOIN structs.struct_type ON struct.type = struct_type.id
            LEFT JOIN structs.planet_attribute mine_clock
                ON mine_clock.id = '12-' || struct.location_id
        WHERE (sa.val & 4) > 0
            AND struct_type.planetary_mining = 'oreMiningRig'
            AND EXISTS (
                SELECT FROM structs.grid
                WHERE grid.id = '0-' || struct.location_id AND grid.val > 0
            )

        UNION ALL

        SELECT
            sa.object_id AS object_id,
            struct.owner AS player_id,
            sa.object_id AS target_id,
            'REFINE'::text AS category,
            COALESCE(refine_clock.val, 0) AS block_start,
            struct_type.ore_refining_difficulty AS difficulty_target,
            struct.location_type,
            struct.location_id,
            CASE WHEN struct.location_type = 'planet' THEN struct.location_id ELSE NULL END AS planet_id
        FROM structs.struct
            INNER JOIN structs.struct_attribute sa
                ON sa.object_id = struct.id AND sa.attribute_type = 'status'
            INNER JOIN structs.struct_type ON struct.type = struct_type.id
            LEFT JOIN structs.planet_attribute refine_clock
                ON refine_clock.id = '13-' || struct.location_id
        WHERE (sa.val & 4) > 0
            AND struct_type.planetary_refinery = 'oreRefinery'
            AND EXISTS (
                SELECT FROM structs.grid
                WHERE grid.id = '0-' || struct.owner AND grid.val > 0
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
                ON raid_clock.id = '10-' || planet.id
            LEFT JOIN structs.planet_attribute shield
                ON shield.id = '0-' || planet.id
        WHERE planet.location_list_start <> '';

    DROP VIEW IF EXISTS view.work_live;

COMMIT;
