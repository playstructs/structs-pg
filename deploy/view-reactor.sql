-- Deploy structs-pg:view-reactor to pg

BEGIN;

CREATE OR REPLACE VIEW view.reactor AS
        SELECT
            id as reactor_id,
            guild_id,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='1-' || reactor.id),0) as fuel_microgram,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='1-' || reactor.id),0)/1000000) as fuel, -- legacy, less accurate

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || reactor.id),0) as load_milliwatt,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='3-' || reactor.id),0)/1000) as load, -- legacy, less accurate

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || reactor.id),0) as capacity_milliwatt,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='2-' || reactor.id),0)/1000) as capacity, -- legacy, less accurate
            validator,
            created_at,
            updated_at
        FROM structs.reactor;

COMMIT;
