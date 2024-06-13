-- Deploy structs-pg:view-planet to pg

BEGIN;

CREATE OR REPLACE VIEW view.planet AS
        SELECT
            id as planet_id,
            max_ore,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='0-' || planet.id),0) as buried_ore,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.id='0-' || planet.owner),0) as available_ore,
            creator,
            owner,
            status,
            created_at,
            updated_at
        FROM structs.planet;

COMMIT;
