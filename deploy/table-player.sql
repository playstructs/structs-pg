-- Deploy structs-pg:table-player to pg

BEGIN;

    CREATE TABLE structs.player (
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

    CREATE TABLE structs.player_address_activity (
        address CHARACTER VARYING PRIMARY KEY,
        player_id CHARACTER VARYING,
        block_height BIGINT,
        block_time TIMESTAMPTZ DEFAULT NOW()
    );
    CREATE UNIQUE INDEX player_address_activity_player_id_idx ON structs.player_address_activity (player_id);

    CREATE TABLE structs.player_address_meta (
        address CHARACTER VARYING PRIMARY KEY,
        ip INET,
        user_agent CHARACTER VARYING,
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE structs.player_address_pending (
        code CHARACTER VARYING,
        address CHARACTER VARYING,
        signature CHARACTER VARYING,
        pubkey CHARACTER VARYING,
        ip INET,
        user_agent CHARACTER VARYING,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        PRIMARY KEY(code, address)
    );

    CREATE TABLE structs.player_address_activation_code (
        player_id CHARACTER VARYING,
        logged_in_address CHARACTER VARYING,
        code CHARACTER VARYING NOT NULL DEFAULT structs.unique_human_random(5, 'player_address_activation_code', 'code'), -- char(5)
        created_at TIMESTAMPTZ DEFAULT NOW(),
        PRIMARY KEY (player_id, code)
    );

    CREATE UNIQUE INDEX player_address_activation_code_idx ON structs.player_address_activation_code (code);

    CREATE TABLE structs.player_external_pending (
        guild_id CHARACTER VARYING,
        primary_address CHARACTER VARYING PRIMARY KEY,
        pubkey CHARACTER VARYING,
        signature CHARACTER VARYING,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );


    CREATE TABLE structs.player_object (
        object_id CHARACTER VARYING PRIMARY KEY,
        player_id CHARACTER VARYING
    );


    CREATE OR REPLACE FUNCTION structs.SET_PLAYER_INTERNAL_PENDING_PROXY(_guild_id CHARACTER VARYING, _address CHARACTER VARYING, _pubkey CHARACTER VARYING, _signature CHARACTER VARYING )
     RETURNS VOID AS
    $BODY$
    BEGIN
        INSERT INTO structs.player_external_pending VALUES (_guild_id, _address, _pubkey, _signature, NOW(), NOW());
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;


    CREATE OR REPLACE FUNCTION structs.GUILD_SIGNING_AGENT()
        RETURNS trigger AS
    $BODY$
    BEGIN
        INSERT INTO structs.player_internal_pending(username, guild_id) VALUES (NEW.id, NEW.id);
        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER
                         COST 100;

    CREATE TRIGGER GUILD_SIGNING_AGENT AFTER INSERT ON structs.guild
        FOR EACH ROW EXECUTE PROCEDURE structs.GUILD_SIGNING_AGENT();


    CREATE TABLE structs.player_discord (
        discord_id TEXT PRIMARY KEY,
        discord_username TEXT,
        guild_id CHARACTER VARYING,
        role_id INTEGER,
        player_id CHARACTER VARYING
    );


    CREATE OR REPLACE FUNCTION structs.DISCORD_PLAYER_SIGNING_AGENT()
        RETURNS trigger AS
    $BODY$
    BEGIN
        INSERT INTO structs.player_internal_pending(username, guild_id) VALUES (NEW.discord_username, NEW.guild_id) RETURNING role_id INTO NEW.role_id;
        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER
                         COST 100;

    CREATE TRIGGER DISCORD_PLAYER_SIGNING_AGENT BEFORE INSERT ON structs.player_discord
        FOR EACH ROW EXECUTE PROCEDURE structs.DISCORD_PLAYER_SIGNING_AGENT();


COMMIT;
