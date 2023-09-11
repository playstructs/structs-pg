-- Deploy structs-pg:table-guild to pg

BEGIN;

CREATE TABLE structs.guild (
	id INTEGER PRIMARY KEY,
	api CHARACTER VARYING,
	public_key CHARACTER VARYING,
	name CHARACTER VARYING,
	logo CHARACTER VARYING,
	socials jsonb,
	website CHARACTER VARYING,
	this_infrastructure bool,
	status CHARACTER VARYING,
	guild_join_type INTEGER,
	infusion_join_minimum INTEGER,
	primary_reactor_id INTEGER,
	entry_substation_id INTEGER,
	creator CHARACTER VARYING,
	created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
