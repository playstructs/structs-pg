-- Deploy structs-pg:table-grid to pg

BEGIN;

CREATE UNLOGGED TABLE structs.grid (
    id          CHARACTER VARYING PRIMARY KEY,
    val         INTEGER,
    updated_at	TIMESTAMPTZ NOT NULL
);

COMMIT;
