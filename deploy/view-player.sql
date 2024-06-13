-- Deploy structs-pg:view-player to pg

BEGIN;

CREATE OR REPLACE VIEW view.player AS
        SELECT
            id as player_id,
            guild_id,
            substation_id,
            planet_id,
            storage->>'amount' as alpha,
            (SELECT grid.val FROM structs.grid WHERE grid.id='0-' || player.id) as ore,
            (SELECT grid.val FROM structs.grid WHERE grid.id='3-' || player.id) as load,
            (SELECT grid.val FROM structs.grid WHERE grid.id='4-' || player.id) as structs_load,
            (SELECT grid.val FROM structs.grid WHERE grid.id='2-' || player.id) as capacity,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || player.substation_id),0) / COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='7-' || player.substation_id),1) as connection_capacity,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || player.id),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='4-' || player.id),0) as total_load,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || player.id),0) + (COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || player.substation_id),0) / COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='7-' || player.substation_id),1)) as total_capacity,
            primary_address,
            created_at,
            updated_at
        FROM structs.player;

COMMIT;

