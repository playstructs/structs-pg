-- Deploy structs-pg:view-work-20251227-greatly-fixed-exclusion-logic to pg

BEGIN;

    DROP VIEW IF EXISTS view.work;

    CREATE OR REPLACE VIEW view.work AS
        WITH work AS (
            -- Building
            SELECT
                struct_attribute.object_id as object_id,
                struct.owner as player_id,
                struct_attribute.object_id as target_id,
                'BUILD' as category,
                COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='2-' || struct.id),0) as block_start,
                struct_type.build_difficulty as difficulty_target
            FROM
                structs.struct_attribute
                    INNER JOIN structs.struct on struct.id = struct_attribute.object_id
                    INNER JOIN structs.struct_type ON struct.type = struct_type.id
            WHERE  struct_attribute.attribute_type = 'status' AND (struct_attribute.val & 34) = 0 -- not built, not destroyed

            UNION

            -- Ore Mining
            SELECT
                struct_attribute.object_id as object_id,
                struct.owner as player_id,
                struct_attribute.object_id as target_id,
                'MINE' as category,
                COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='3-' || struct.id),0) as block_start,
                struct_type.ore_mining_difficulty as difficulty_target
            FROM
                structs.struct_attribute
                    INNER JOIN structs.struct on struct.id = struct_attribute.object_id
                    INNER JOIN structs.struct_type ON struct.type = struct_type.id
            WHERE
                  struct_attribute.attribute_type = 'status'
                AND (struct_attribute.val & 4) > 0
                AND struct_type.planetary_mining = 'oreMiningRig'
                AND EXISTS (SELECT FROM structs.grid where grid.id = '0-' || struct.location_id and grid.val > 0 )

            UNION

            -- Ore Refinement
            SELECT
                struct_attribute.object_id as object_id,
                struct.owner as player_id,
                struct_attribute.object_id as target_id,
                'REFINE' as category,
                COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='4-' || struct.id),0) as block_start,
                struct_type.ore_refining_difficulty as difficulty_target
            FROM
                structs.struct_attribute
                    INNER JOIN structs.struct on struct.id = struct_attribute.object_id
                    INNER JOIN structs.struct_type ON struct.type = struct_type.id
            WHERE
                  struct_attribute.attribute_type = 'status'
                AND (struct_attribute.val & 4) > 0
                AND struct_type.planetary_refinery = 'oreRefinery'
                AND EXISTS (SELECT FROM structs.grid where grid.id = '0-' || struct.owner and grid.val > 0 )

            UNION

            -- Planetary Raiding
            SELECT
                planet.location_list_start as object_id,
                (select fleet.owner FROM structs.fleet WHERE fleet.id = planet.location_list_start) as player_id,
                planet.id as target_id,
                'RAID' as category,
                COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='10-' || planet.id),0) as  block_start,
                COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='0-' || planet.id),0) as difficulty_target
            FROM structs.planet where location_list_start <> ''
        )
        SELECT * FROM work WHERE work.block_start > 0;

COMMIT;

