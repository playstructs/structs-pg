-- Deploy structs-pg:view-player-20260901-fix-total-load-capacity to pg
--
-- Fix operator-precedence bug on total_load and total_capacity display
-- columns: division must apply to the full sum, not only the second term.
-- total_load_p / total_capacity_p were already correct.

BEGIN;

    CREATE OR REPLACE VIEW view.player AS
        SELECT
            player.id as player_id,
            player.username,
            player.pfp,
            player.pfp_client_render_attributes,
            player.guild_id,
            player.substation_id,
            player.planet_id,
            player.fleet_id,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='ore'),0) as ore,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) as load_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0)/1000) as load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0) as structs_load_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0)/1000) as structs_load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) as capacity_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0)/1000) as capacity,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0) as connection_capacity_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0)/1000) as connection_capacity,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0) as total_load_p,
            structs.UNIT_LEGACY_FORMAT(
                COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0),
                'milliwatt'
            ) as total_load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0)  as total_capacity_p,
            structs.UNIT_LEGACY_FORMAT(
                COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0),
                'milliwatt'
            ) as total_capacity,

            player.primary_address,
            player.created_at,
            player.updated_at
        FROM structs.player;

COMMIT;
