-- Deploy structs-pg:view-planet to pg

BEGIN;

CREATE OR REPLACE VIEW view.planet AS
        SELECT
            id as planet_id,
            max_ore,
            (SELECT grid.val FROM structs.grid WHERE grid.id='0-' || planet.id) as buried_ore,
            (SELECT grid.val FROM structs.grid WHERE grid.id='0-' || planet.owner) as available_ore,
            creator,
            owner,
            status,
            created_at,
            updated_at
        FROM structs.planet;

COMMIT;
