-- Deploy structs-pg:table-substation to pg

BEGIN;

CREATE TABLE structs.substation (
	id INTEGER PRIMARY KEY,

	player_connection_allocation INTEGER,

	owner INTEGER,
	creator CHARACTER VARYING,

	load INTEGER,
	energy INTEGER,
	connected_player_count INTEGER,

	created_at TIMESTAMPTZ NOT NULL, 
	updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
