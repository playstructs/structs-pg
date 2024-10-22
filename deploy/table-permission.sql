-- Deploy structs-pg:table-permission to pg

BEGIN;

CREATE TABLE structs.permission (
   id           CHARACTER VARYING PRIMARY KEY,
   object_type  CHARACTER VARYING,
   object_index CHARACTER VARYING,
   object_id    CHARACTER VARYING,
   player_id    CHARACTER VARYING,
   val          INTEGER,
   updated_at	TIMESTAMPTZ NOT NULL
);

COMMIT;
