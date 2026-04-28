-- Revert structs-pg:function-signer-tx-20260427-ugc-overhaul from pg
--
-- Drops the 12 new tx_* wrappers and restores signer.UPDATE_PENDING_ACCOUNT
-- to its prior PermAll constant (16777215). The prior body is reproduced
-- verbatim from function-signer-tx-20260325-permission-overhaul.sql.

BEGIN;

    DROP FUNCTION IF EXISTS signer.tx_guild_update_name(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_guild_update_pfp(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_player_update_name(CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_player_update_pfp(CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_substation_update_name(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_substation_update_pfp(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_planet_update_name(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);

    DROP FUNCTION IF EXISTS signer.tx_guild_moderate_player_name(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_guild_moderate_player_pfp(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_guild_moderate_substation_name(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_guild_moderate_substation_pfp(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_guild_moderate_planet_name(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);

    CREATE OR REPLACE FUNCTION signer.UPDATE_PENDING_ACCOUNT(_account_id INTEGER, _player_id CHARACTER VARYING, _address CHARACTER VARYING, _pubkey CHARACTER VARYING, _signature CHARACTER VARYING, _permission INTEGER) RETURNS VOID AS
    $BODY$
    BEGIN
        UPDATE signer.account SET address=_address, status='pending' WHERE id=_account_id;

        INSERT INTO signer.tx (object_id, module, command, args, permission_requirement )
            VALUES (_player_id, 'structs', 'address-register', jsonb_build_array(_address , _pubkey ,_signature , _permission), 16777215);
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE COST 100;

COMMIT;
