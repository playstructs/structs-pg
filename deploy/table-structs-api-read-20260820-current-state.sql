-- Deploy structs-pg:table-structs-api-read-20260820-current-state to pg
--
-- Empty, indexer-maintained current-state models for predictable API reads.
-- The api_ prefix distinguishes derived projections from authoritative state.

BEGIN;

    CREATE TABLE structs.api_refresh_state (
        model         TEXT PRIMARY KEY,
        source_height BIGINT NOT NULL CHECK (source_height >= 0),
        source_time   TIMESTAMPTZ,
        refreshed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE structs.api_leaderboard_player (
        player_id     CHARACTER VARYING PRIMARY KEY,
        username      CHARACTER VARYING,
        guild_id      CHARACTER VARYING,
        alpha_balance NUMERIC NOT NULL,
        alpha_value   NUMERIC
    );

    CREATE INDEX api_leaderboard_player_alpha_balance_idx
        ON structs.api_leaderboard_player (alpha_balance DESC, player_id);
    CREATE INDEX api_leaderboard_player_alpha_value_idx
        ON structs.api_leaderboard_player
        (alpha_value DESC NULLS LAST, player_id);

    CREATE TABLE structs.api_leaderboard_guild (
        guild_id                   CHARACTER VARYING PRIMARY KEY,
        name                       CHARACTER VARYING,
        onchain_name               CHARACTER VARYING,
        player_count               BIGINT NOT NULL CHECK (player_count >= 0),
        collateral                 NUMERIC,
        supply                     NUMERIC,
        ratio                      NUMERIC GENERATED ALWAYS AS
                                   (collateral / NULLIF(supply, 0)) STORED,
        member_capacity            NUMERIC NOT NULL,
        member_load                NUMERIC NOT NULL,
        shared_connection_capacity NUMERIC NOT NULL
    );

    CREATE INDEX api_leaderboard_guild_collateral_idx
        ON structs.api_leaderboard_guild
        (collateral DESC NULLS LAST, guild_id);
    CREATE INDEX api_leaderboard_guild_ratio_idx
        ON structs.api_leaderboard_guild (ratio DESC NULLS LAST, guild_id);
    CREATE INDEX api_leaderboard_guild_player_count_idx
        ON structs.api_leaderboard_guild (player_count DESC, guild_id);

    CREATE TABLE structs.api_leaderboard_reactor (
        reactor_id CHARACTER VARYING PRIMARY KEY,
        fuel       NUMERIC NOT NULL,
        power      NUMERIC NOT NULL
    );

    CREATE INDEX api_leaderboard_reactor_fuel_idx
        ON structs.api_leaderboard_reactor (fuel DESC, reactor_id);
    CREATE INDEX api_leaderboard_reactor_power_idx
        ON structs.api_leaderboard_reactor (power DESC, reactor_id);

    CREATE TABLE structs.api_leaderboard_substation (
        substation_id              CHARACTER VARYING PRIMARY KEY,
        owner                      CHARACTER VARYING,
        load                       NUMERIC NOT NULL,
        member_capacity            NUMERIC NOT NULL,
        shared_connection_capacity NUMERIC NOT NULL,
        player_count               BIGINT NOT NULL CHECK (player_count >= 0)
    );

    CREATE INDEX api_leaderboard_substation_load_idx
        ON structs.api_leaderboard_substation (load DESC, substation_id);
    CREATE INDEX api_leaderboard_substation_member_capacity_idx
        ON structs.api_leaderboard_substation
        (member_capacity DESC, substation_id);
    CREATE INDEX api_leaderboard_substation_connection_capacity_idx
        ON structs.api_leaderboard_substation
        (shared_connection_capacity DESC, substation_id);
    CREATE INDEX api_leaderboard_substation_player_count_idx
        ON structs.api_leaderboard_substation
        (player_count DESC, substation_id);

    CREATE TABLE structs.api_leaderboard_provider (
        provider_id     CHARACTER VARYING PRIMARY KEY,
        owner           CHARACTER VARYING,
        rate_amount     NUMERIC,
        rate_denom      CHARACTER VARYING,
        agreement_count BIGINT NOT NULL CHECK (agreement_count >= 0)
    );

    CREATE INDEX api_leaderboard_provider_rate_idx
        ON structs.api_leaderboard_provider
        (rate_denom, rate_amount, provider_id);
    CREATE INDEX api_leaderboard_provider_agreement_count_idx
        ON structs.api_leaderboard_provider
        (agreement_count DESC, provider_id);

    CREATE TABLE structs.api_inventory (
        owner_type structs.object_type NOT NULL,
        owner_id   CHARACTER VARYING NOT NULL,
        denom      TEXT NOT NULL,
        balance    NUMERIC NOT NULL,
        PRIMARY KEY (owner_type, owner_id, denom)
    );

    CREATE TABLE structs.api_guild_bank (
        guild_id   CHARACTER VARYING NOT NULL,
        denom      TEXT NOT NULL,
        collateral NUMERIC,
        supply     NUMERIC,
        ratio      NUMERIC GENERATED ALWAYS AS
                   (collateral / NULLIF(supply, 0)) STORED,
        PRIMARY KEY (guild_id, denom)
    );

COMMIT;
