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

COMMIT;
