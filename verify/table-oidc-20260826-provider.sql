-- Verify structs-pg:table-oidc-20260826-provider on pg

BEGIN;

    SELECT client_id, guild_id, client_secret_hash, redirect_uris, scopes, enabled
      FROM structs.oidc_client WHERE FALSE;

    SELECT request_id, client_id, redirect_uri, code_challenge, expires_at
      FROM structs.oidc_authorization_request WHERE FALSE;

    SELECT code_hash, client_id, player_id, nonce, expires_at, consumed_at
      FROM structs.oidc_authorization_code WHERE FALSE;

    SELECT jti, client_id, player_id, auth_code_id, expires_at, revoked_at
      FROM structs.oidc_access_token WHERE FALSE;

    DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM cron.job WHERE jobname = 'oidc_cleaner'
        ) THEN
            RAISE EXCEPTION 'oidc_cleaner cron job is not scheduled';
        END IF;
    END
    $$;

ROLLBACK;
