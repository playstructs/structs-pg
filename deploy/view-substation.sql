-- Deploy structs-pg:view-substation to pg

BEGIN;

CREATE OR REPLACE VIEW view.substation AS
        SELECT
            id as substation_id,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || substation.id),0) as load_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || substation.id),0)/1000) as load, -- legacy, less accurate

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || substation.id),0) as capacity_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || substation.id),0)/1000) as capacity, -- legacy, less accurate

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='6-' || substation.id),0) as connection_capacity_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='6-' || substation.id),0)/1000) as connection_capacity, -- legacy, less accurate

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='7-' || substation.id),0) as connection_count,
            owner,
            created_at,
            updated_at
        FROM structs.substation;



    CREATE OR REPLACE VIEW view.leaderboard_substation AS
    WITH base as (SELECT
                      id,
                      COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || substation.id),0) as load,
                      COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || substation.id),0) as capacity,
                      COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='6-' || substation.id),0) as connection_capacity,
                      COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='7-' || substation.id),0) as player_count,
                      owner
                  FROM structs.substation)
    SELECT
        base.id,
        base.load,
        structs.UNIT_DISPLAY_FORMAT(base.load, 'milliwatt') as display_load,
        base.capacity,
        structs.UNIT_DISPLAY_FORMAT(base.capacity, 'milliwatt') as display_capacity,
        CASE base.capacity WHEN 0 THEN 0 ELSE (base.load / base.capacity) END as ratio,
        CASE base.capacity WHEN 0 THEN '0%' ELSE ROUND((base.load / base.capacity)*100,2) || '%' END as display_ratio,
        base.connection_capacity,
        structs.UNIT_DISPLAY_FORMAT(base.connection_capacity, 'milliwatt') as display_connection_capacity,
        base.player_count,
        base.owner,
        player_discord.discord_username
    FROM base LEFT JOIN structs.player_discord ON player_discord.player_id = base.owner;


COMMIT;
