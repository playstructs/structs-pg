-- Deploy structs-pg:view-reactor to pg

BEGIN;

CREATE OR REPLACE VIEW view.reactor AS
        SELECT
            id as reactor_id,
            guild_id,
            (SELECT grid.val FROM structs.grid WHERE grid.id='1-' || reactor.id) as fuel,
            (SELECT grid.val FROM structs.grid WHERE grid.id='3-' || reactor.id) as load,
            (SELECT grid.val FROM structs.grid WHERE grid.id='2-' || reactor.id) as capacity,
            validator,
            created_at,
            updated_at
        FROM structs.reactor;

COMMIT;
