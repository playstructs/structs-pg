-- Deploy structs-pg:view-struct to pg

BEGIN;

CREATE OR REPLACE VIEW view.struct AS
        SELECT
            struct.id as struct_id,
            index,

            location_type,
            location_id,
            operating_ambit,
            slot,

            COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='0-' || struct.id),0) as  health,
            COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='1-' || struct.id),0) as  status,

            COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='2-' || struct.id),0) as  block_start_build,
            COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='3-' || struct.id),0) as  block_start_ore_mine,
            COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='4-' || struct.id),0) as  block_start_ore_refine,

            COALESCE((SELECT struct_attribute.val FROM structs.struct_attribute WHERE struct_attribute.id='5-' || struct.id),0) as  protected_struct_index,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='1-' || struct.id),0) as generator_fuel_microgram,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='1-' || struct.id),0)/1000000) as generator_fuel,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || struct.id),0) as generator_load_milliwatt,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || struct.id),0)/1000) as generator_load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || struct.id),0) as generator_capacity_milliwatt,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || struct.id),0)/1000) as generator_capacity,

            struct_type.*,

            struct.creator,
            struct.owner,
            struct.created_at as struct_created_at,
            struct.updated_at as struct_updated_at
        FROM structs.struct, structs.struct_type
        WHERE struct_type.id = struct.type;


    CREATE OR REPLACE VIEW view.struct_status AS
    SELECT
        struct_attribute.object_id as struct_id,
        (struct_attribute.val & 1) > 0 as materialized,
        (struct_attribute.val & 2) > 0 as built,
        (struct_attribute.val & 4) > 0 as online,
        (struct_attribute.val & 8) > 0 as stored,
        (struct_attribute.val & 16) > 0 as hidden,
        (struct_attribute.val & 32) > 0 as destroyed,
        (struct_attribute.val & 64) > 0 as locked,
        struct_attribute.updated_at
    FROM structs.struct_attribute
    WHERE struct_attribute.attribute_type = 'status';


COMMIT;

