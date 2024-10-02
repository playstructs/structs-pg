-- Deploy structs-pg:view-grid to pg

BEGIN;

CREATE OR REPLACE VIEW view.grid AS
        SELECT
            grid.*
        FROM structs.grid;

COMMIT;
