-- Revert structs-pg:table-oidc-20260826-provider from pg

BEGIN;

    SELECT cron.unschedule('oidc_cleaner');

    DROP PROCEDURE IF EXISTS structs.CLEAN_OIDC();

    DROP TABLE IF EXISTS structs.oidc_access_token;
    DROP TABLE IF EXISTS structs.oidc_authorization_code;
    DROP TABLE IF EXISTS structs.oidc_authorization_request;
    DROP TABLE IF EXISTS structs.oidc_client;

COMMIT;
