-- Deploy structs-pg:table-player to pg

BEGIN;

CREATE UNLOGGED TABLE structs.player (
	id CHARACTER VARYING PRIMARY KEY,
    index INTEGER,

    primary_address CHARACTER VARYING,

    guild_id CHARACTER VARYING,
	substation_id CHARACTER VARYING,
	planet_id CHARACTER VARYING,

	storage jsonb,

	created_at TIMESTAMPTZ NOT NULL,
	updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE structs.player_meta (
    id CHARACTER VARYING PRIMARY KEY,

    username CHARACTER VARYING,
    pfp CHARACTER VARYING,

    status CHARACTER VARYING,

    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE structs.player_pending (
    primary_address CHARACTER VARYING PRIMARY KEY,
    signature bytea,
    username CHARACTER VARYING,
    pfp CHARACTER VARYING,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE UNLOGGED TABLE structs.player_address (
    address CHARACTER VARYING PRIMARY KEY,
    player_id CHARACTER VARYING,
    status CHARACTER VARYING,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE UNLOGGED TABLE structs.player_address_activity (
    address CHARACTER VARYING PRIMARY KEY,
    block_height INTEGER,
    block_time TIMESTAMPTZ NOT NULL
);

CREATE TABLE structs.player_address_meta (
    address CHARACTER VARYING PRIMARY KEY,
    ip INET,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE structs.player_address_pending (
    address CHARACTER VARYING PRIMARY KEY,
    signature bytea,
    code CHARACTER VARYING,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
