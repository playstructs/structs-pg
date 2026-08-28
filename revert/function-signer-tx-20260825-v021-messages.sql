-- Revert structs-pg:function-signer-tx-20260825-v021-messages from pg

BEGIN;

    DROP FUNCTION IF EXISTS signer.tx_guild_bank_convert(CHARACTER VARYING, CHARACTER VARYING, NUMERIC, NUMERIC);
    DROP FUNCTION IF EXISTS signer.tx_guild_bank_convert_token(CHARACTER VARYING, NUMERIC, CHARACTER VARYING, CHARACTER VARYING, NUMERIC);
    DROP FUNCTION IF EXISTS signer.tx_guild_update_bank_convert_in_fee(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_guild_update_bank_convert_out_fee(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_reactor_restart(CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_guild_create_charter(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);

    DROP FUNCTION IF EXISTS signer.tx_guild_bank_redeem(CHARACTER VARYING, NUMERIC, CHARACTER VARYING, NUMERIC);
    CREATE FUNCTION signer.tx_guild_bank_redeem(
        _player_id CHARACTER VARYING,
        _amount    NUMERIC,
        _denom     CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    DECLARE
        _real_denom  CHARACTER VARYING;
        _real_amount NUMERIC;
    BEGIN
        IF _denom ILIKE 'u%' THEN
            _real_denom  := _denom;
            _real_amount := _amount;
        ELSE
            _real_denom  := 'u' || _denom;
            _real_amount := _amount * 10^6;
        END IF;

        PERFORM signer.CREATE_TRANSACTION(_player_id,16,'structs','guild-bank-redeem',jsonb_build_array(_real_amount || _real_denom),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    DROP FUNCTION IF EXISTS signer.tx_guild_bank_mint(CHARACTER VARYING, NUMERIC, NUMERIC, CHARACTER VARYING);
    CREATE FUNCTION signer.tx_guild_bank_mint(
        _player_id    CHARACTER VARYING,
        _amount_alpha NUMERIC,
        _amount_token NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8192,'structs','guild-bank-mint',jsonb_build_array(_amount_alpha, _amount_token),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    DROP FUNCTION IF EXISTS signer.tx_guild_bank_confiscate_and_burn(CHARACTER VARYING, NUMERIC, CHARACTER VARYING, CHARACTER VARYING);
    CREATE FUNCTION signer.tx_guild_bank_confiscate_and_burn(
        _player_id    CHARACTER VARYING,
        _address      CHARACTER VARYING,
        _amount_token NUMERIC
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,4096,'structs','guild-bank-confiscate-and-burn',jsonb_build_array(_address, _amount_token),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    DROP FUNCTION IF EXISTS signer.tx_guild_update_entry_rank(CHARACTER VARYING, CHARACTER VARYING, BIGINT);
    CREATE FUNCTION signer.tx_guild_update_entry_rank(
        _guild_id       CHARACTER VARYING,
        _new_entry_rank BIGINT
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,32768,'structs','guild-update-entry-rank',jsonb_build_array(_new_entry_rank),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    DROP FUNCTION IF EXISTS signer.tx_player_update_guild_rank(CHARACTER VARYING, BIGINT, CHARACTER VARYING);
    CREATE FUNCTION signer.tx_player_update_guild_rank(
        _target_player_id CHARACTER VARYING,
        _guild_rank       BIGINT
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_target_player_id,512,'structs','player-update-guild-rank',jsonb_build_array(_target_player_id, _guild_rank),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
