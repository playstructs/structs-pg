-- Deploy structs-pg:view-reactor to pg

BEGIN;

CREATE OR REPLACE VIEW view.reactor AS
        SELECT
            id as reactor_id,
            guild_id,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='1-' || reactor.id),0) as fuel_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='1-' || reactor.id),0)/1000000) as fuel, -- legacy, less accurate

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || reactor.id),0) as load_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || reactor.id),0)/1000) as load, -- legacy, less accurate

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || reactor.id),0) as capacity_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || reactor.id),0)/1000) as capacity, -- legacy, less accurate
            validator,
            created_at,
            updated_at
        FROM structs.reactor;


    CREATE OR REPLACE VIEW view.leaderboard_reactor AS
    WITH base AS (select destination_id as id,
                         sum(fuel_p)  as fuel,
                         sum(power_p) as power
                  from structs.infusion
                  where destination_type = 'reactor'
                  group by destination_id
    ) SELECT id,
             fuel,
             structs.UNIT_DISPLAY_FORMAT(fuel, 'ualpha') as display_fuel,
             power,
             structs.UNIT_DISPLAY_FORMAT(power, 'milliwatt') as display_power
    FROM base;

COMMIT;


