-- Deploy structs-pg:table-permission to pg

BEGIN;

CREATE UNLOGGED TABLE structs.permission (
   id           CHARACTER VARYING PRIMARY KEY,
   object_type  INTEGER,
   object_index CHARACTER VARYING,
   player_id    CHARACTER VARYING,
   val          INTEGER,
   updated_at	TIMESTAMPTZ NOT NULL
);

COMMIT;
