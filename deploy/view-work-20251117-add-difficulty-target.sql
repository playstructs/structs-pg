-- Deploy structs-pg:view-work-20251117-add-difficulty-target to pg

BEGIN;

    DROP VIEW IF EXISTS view.work;

    CREATE OR REPLACE VIEW view.work AS
        WITH work AS (
            SELECT
                struct.id as object_id,
                struct.owner as worker_id,
                'BUILD' as category,
                COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='2-' || struct.id),0) as block_start,
                (SELECT struct_type.build_difficulty FROM structs.struct_type where struct_type.id = struct.type) as difficulty_target
            FROM structs.struct
            UNION
            SELECT
                struct.id as object_id,
                struct.owner as worker_id,
                'MINE' as category,
                COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='3-' || struct.id),0) as  block_start,
                (SELECT struct_type.ore_mining_difficulty FROM structs.struct_type where struct_type.id = struct.type) as difficulty_target
            FROM structs.struct
            UNION
            SELECT
                struct.id as object_id,
                struct.owner as worker_id,
                'REFINE' as category,
                COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='4-' || struct.id),0) as  block_start,
                (SELECT struct_type.ore_refining_difficulty FROM structs.struct_type where struct_type.id = struct.type) as difficulty_target
            FROM structs.struct
            UNION
            SELECT
                planet.id as object_id,
                planet.location_list_start as worker_id,
                'RAID' as category,
                COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='10-' || planet.id),0) as  block_start,
                COALESCE((SELECT planet_attribute.val FROM structs.planet_attribute WHERE planet_attribute.id='0-' || planet.id),0) as difficulty_target
            FROM structs.planet
        )
        SELECT * FROM work WHERE work.block_start > 0;

COMMIT;

