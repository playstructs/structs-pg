-- Deploy structs-pg:view-substation to pg

BEGIN;

CREATE OR REPLACE VIEW view.substation AS
        SELECT
            id as substation_id,
            (SELECT grid.val FROM structs.grid WHERE grid.id='3-' || substation.id) as load,
            (SELECT grid.val FROM structs.grid WHERE grid.id='2-' || substation.id) as capacity,
            (SELECT grid.val FROM structs.grid WHERE grid.id='6-' || substation.id) as connection_capacity,
            (SELECT grid.val FROM structs.grid WHERE grid.id='7-' || substation.id) as connection_count,
            owner,
            created_at,
            updated_at
        FROM structs.substation;

COMMIT;
