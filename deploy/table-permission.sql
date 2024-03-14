-- Deploy structs-pg:table-permission to pg

BEGIN;

CREATE UNLOGGED TABLE structs.permission (
   id           CHARACTER VARYING PRIMARY KEY,
   val          INTEGER,
   updated_at	TIMESTAMPTZ NOT NULL
);

COMMIT;
