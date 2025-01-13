-- Deploy structs-pg:table-player to pg

BEGIN;

CREATE UNLOGGED TABLE structs.player (
	id CHARACTER VARYING PRIMARY KEY,
    index INTEGER,

    creator CHARACTER VARYING,
    primary_address CHARACTER VARYING,

    guild_id CHARACTER VARYING,
	substation_id CHARACTER VARYING,
	planet_id CHARACTER VARYING,
    fleet_id CHARACTER VARYING,

	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE structs.player_meta (
    id CHARACTER VARYING,
    guild_id CHARACTER VARYING,

    username CHARACTER VARYING,
    pfp CHARACTER VARYING,

    status CHARACTER VARYING,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id, guild_id)
);

CREATE TABLE structs.player_pending (
    primary_address CHARACTER VARYING PRIMARY KEY,
    guild_id CHARACTER VARYING,
    signature CHARACTER VARYING,
    pubkey CHARACTER VARYING,
    username CHARACTER VARYING,
    pfp CHARACTER VARYING,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE structs.player_internal_pending (
    username CHARACTER VARYING PRIMARY KEY,
    guild_id CHARACTER VARYING,
    pfp CHARACTER VARYING,
    primary_address CHARACTER VARYING,
    role_id INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE structs.player_address (
    address CHARACTER VARYING PRIMARY KEY,
    player_id CHARACTER VARYING,
    guild_id CHARACTER VARYING,
    status CHARACTER VARYING,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNLOGGED TABLE structs.player_address_activity (
    address CHARACTER VARYING PRIMARY KEY,
    block_height INTEGER,
    block_time TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE structs.player_address_meta (
    address CHARACTER VARYING PRIMARY KEY,
    ip INET,
    user_agent CHARACTER VARYING,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNLOGGED TABLE structs.player_address_pending (
    address CHARACTER VARYING PRIMARY KEY,
    signature CHARACTER VARYING,
    pubkey CHARACTER VARYING,
    code CHARACTER VARYING NOT NULL DEFAULT structs.unique_human_random(5, 'player_address_pending', 'code'), -- char(5)
    ip INET,
    user_agent CHARACTER VARYING,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX player_address_pending_code_idx ON structs.player_address_pending (code);


COMMIT;
