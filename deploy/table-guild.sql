-- Deploy structs-pg:table-guild to pg

BEGIN;

CREATE TABLE structs.guild (
	id INTEGER PRIMARY KEY,
    index INTEGER,

	endpoint CHARACTER VARYING,

	join_infusion_minimum INTEGER,
	join_infusion_minimum_bypass_by_request INTEGER,
    join_infusion_minimum_bypass_by_invite INTEGER,

    primary_reactor_id CHARACTER VARYING,
	entry_substation_id CHARACTER VARYING,

	creator CHARACTER VARYING,
    owner CHARACTER VARYING,
	created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE structs.guild_meta (
    id INTEGER PRIMARY KEY,

    name CHARACTER VARYING,
    tag CHARACTER VARYING,
    logo CHARACTER VARYING,
    socials jsonb,
    website CHARACTER VARYING,
    this_infrastructure bool,
    status CHARACTER VARYING,

    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
