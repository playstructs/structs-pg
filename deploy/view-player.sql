-- Deploy structs-pg:view-player to pg

BEGIN;

CREATE OR REPLACE VIEW view.player AS
        SELECT
            id as player_id,
            guild_id,
            substation_id,
            planet_id,
            fleet_id,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='0-' || player.id),0) as ore,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || player.id),0) as load,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='4-' || player.id),0) as structs_load,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || player.id),0) as capacity,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='6-' || player.substation_id),0) as connection_capacity,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || player.id),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='4-' || player.id),0) as total_load,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || player.id),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='6-' || player.substation_id),0)  as total_capacity,
            primary_address,
            created_at,
            updated_at
        FROM structs.player;


COMMIT;

