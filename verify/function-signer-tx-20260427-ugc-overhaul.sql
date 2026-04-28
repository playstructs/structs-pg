-- Verify structs-pg:function-signer-tx-20260427-ugc-overhaul on pg

BEGIN;

    -- Self-service UGC functions
    SELECT 'signer.tx_guild_update_name(character varying, character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_guild_update_pfp(character varying, character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_player_update_name(character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_player_update_pfp(character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_substation_update_name(character varying, character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_substation_update_pfp(character varying, character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_planet_update_name(character varying, character varying, character varying)'::regprocedure;

    -- Guild-moderation UGC functions
    SELECT 'signer.tx_guild_moderate_player_name(character varying, character varying, character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_guild_moderate_player_pfp(character varying, character varying, character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_guild_moderate_substation_name(character varying, character varying, character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_guild_moderate_substation_pfp(character varying, character varying, character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_guild_moderate_planet_name(character varying, character varying, character varying, character varying)'::regprocedure;

    -- UPDATE_PENDING_ACCOUNT must use the new PermAll = 33554431
    DO $$
    DECLARE
        body text;
    BEGIN
        SELECT pg_get_functiondef('signer.update_pending_account(integer,character varying,character varying,character varying,character varying,integer)'::regprocedure)
        INTO body;
        IF body NOT LIKE '%33554431%' THEN
            RAISE EXCEPTION 'signer.UPDATE_PENDING_ACCOUNT does not reference new PermAll constant 33554431';
        END IF;
    END
    $$;

ROLLBACK;
