-- Deploy structs-pg:table-oidc-20260826-provider to pg
--
-- The guild webapp acts as an OpenID Connect provider so Matrix
-- Authentication Service can use a Structs session as its upstream identity.
-- These tables hold the OAuth client registry and the short-lived state of
-- in-flight authorization-code flows. They never hold wallet material.

BEGIN;

    CREATE TABLE structs.oidc_client (
        client_id          CHARACTER VARYING PRIMARY KEY,
        guild_id           CHARACTER VARYING NOT NULL,
        name               CHARACTER VARYING,
        client_secret_hash CHARACTER VARYING,
        redirect_uris      CHARACTER VARYING[] NOT NULL DEFAULT '{}',
        scopes             CHARACTER VARYING[] NOT NULL DEFAULT '{}',
        is_confidential    BOOLEAN NOT NULL DEFAULT TRUE,
        enabled            BOOLEAN NOT NULL DEFAULT TRUE,
        created_at         TIMESTAMPTZ DEFAULT NOW(),
        updated_at         TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE structs.oidc_authorization_request (
        request_id            CHARACTER VARYING PRIMARY KEY,
        client_id             CHARACTER VARYING NOT NULL,
        redirect_uri          CHARACTER VARYING NOT NULL,
        response_type         CHARACTER VARYING NOT NULL,
        scope                 CHARACTER VARYING,
        state                 CHARACTER VARYING,
        nonce                 CHARACTER VARYING,
        code_challenge        CHARACTER VARYING,
        code_challenge_method CHARACTER VARYING,
        expires_at            TIMESTAMPTZ NOT NULL,
        consumed_at           TIMESTAMPTZ,
        created_at            TIMESTAMPTZ DEFAULT NOW(),
        updated_at            TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE structs.oidc_authorization_code (
        code_hash             CHARACTER VARYING PRIMARY KEY,
        client_id             CHARACTER VARYING NOT NULL,
        player_id             CHARACTER VARYING NOT NULL,
        redirect_uri          CHARACTER VARYING NOT NULL,
        scope                 CHARACTER VARYING,
        nonce                 CHARACTER VARYING,
        code_challenge        CHARACTER VARYING,
        code_challenge_method CHARACTER VARYING,
        expires_at            TIMESTAMPTZ NOT NULL,
        consumed_at           TIMESTAMPTZ,
        created_at            TIMESTAMPTZ DEFAULT NOW(),
        updated_at            TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE structs.oidc_access_token (
        jti          CHARACTER VARYING PRIMARY KEY,
        client_id    CHARACTER VARYING NOT NULL,
        player_id    CHARACTER VARYING,
        auth_code_id CHARACTER VARYING,
        scope        CHARACTER VARYING,
        expires_at   TIMESTAMPTZ NOT NULL,
        revoked_at   TIMESTAMPTZ,
        created_at   TIMESTAMPTZ DEFAULT NOW(),
        updated_at   TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX oidc_authorization_request_expires_at_idx
        ON structs.oidc_authorization_request (expires_at);
    CREATE INDEX oidc_authorization_code_expires_at_idx
        ON structs.oidc_authorization_code (expires_at);
    CREATE INDEX oidc_access_token_expires_at_idx
        ON structs.oidc_access_token (expires_at);
    CREATE INDEX oidc_access_token_player_id_idx
        ON structs.oidc_access_token (player_id);
    CREATE INDEX oidc_access_token_auth_code_id_idx
        ON structs.oidc_access_token (auth_code_id);

    CREATE OR REPLACE PROCEDURE structs.CLEAN_OIDC()
    AS
    $BODY$
    BEGIN
        DELETE FROM structs.oidc_authorization_request
            WHERE expires_at + '1 hour'::interval < NOW();
        DELETE FROM structs.oidc_authorization_code
            WHERE expires_at + '1 hour'::interval < NOW();
        DELETE FROM structs.oidc_access_token
            WHERE expires_at + '1 day'::interval < NOW();
    END
    $BODY$ LANGUAGE plpgsql SECURITY DEFINER;

    SELECT cron.schedule('oidc_cleaner', '59 seconds', 'CALL structs.CLEAN_OIDC();');

COMMIT;
