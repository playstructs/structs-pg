-- Revert structs-pg:function-signer-tx-20261030-guild-bank from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.tx IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract='v022-1' AND command IN
        ('guild-bank-mint','guild-bank-confiscate-and-burn','guild-bank-convert','guild-bank-redeem',
        'guild-bank-convert-token','guild-update-bank-convert-in-fee','guild-update-bank-convert-out-fee')) THEN
        RAISE EXCEPTION 'versioned guild-bank requests exist; retain their contract or restore a verified checkpoint';
    END IF;
END $$;
CREATE OR REPLACE FUNCTION signer.tx_guild_bank_confiscate_and_burn(_player_id character varying, _amount_token numeric, _address character varying, _guild_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _player_id,
            4096,
            'structs',
            'guild-bank-confiscate-and-burn',
            jsonb_build_array(_amount_token, _address),
            jsonb_build_object('guild-id', _guild_id)
        );
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_bank_convert(_player_id character varying, _guild_id character varying, _amount_alpha numeric, _min_amount_token numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _player_id,
            16,
            'structs',
            'guild-bank-convert',
            jsonb_build_array(_guild_id, _amount_alpha, _min_amount_token),
            '{}'
        );
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_bank_convert_token(_player_id character varying, _amount_token numeric, _denom character varying, _target_guild_id character varying, _min_amount_token numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    DECLARE
        _real_denom  CHARACTER VARYING;
        _real_amount NUMERIC;
    BEGIN
        IF _denom ILIKE 'u%' THEN
            _real_denom  := _denom;
            _real_amount := _amount_token;
        ELSE
            _real_denom  := 'u' || _denom;
            _real_amount := _amount_token * 10^6;
        END IF;

        PERFORM signer.CREATE_TRANSACTION(
            _player_id,
            16,
            'structs',
            'guild-bank-convert-token',
            jsonb_build_array(_real_amount || _real_denom, _target_guild_id, _min_amount_token),
            '{}'
        );
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_bank_mint(_player_id character varying, _amount_alpha numeric, _amount_token numeric, _guild_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _player_id,
            8192,
            'structs',
            'guild-bank-mint',
            jsonb_build_array(_amount_alpha, _amount_token),
            jsonb_build_object('guild-id', _guild_id)
        );
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_bank_redeem(_player_id character varying, _amount numeric, _denom character varying, _min_amount_alpha numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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

        PERFORM signer.CREATE_TRANSACTION(
            _player_id,
            16,
            'structs',
            'guild-bank-redeem',
            jsonb_build_array(_real_amount || _real_denom, _min_amount_alpha),
            '{}'
        );
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_update_bank_convert_in_fee(_player_id character varying, _guild_id character varying, _fee character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _guild_id,
            2,
            'structs',
            'guild-update-bank-convert-in-fee',
            jsonb_build_array(_guild_id, _fee),
            '{}'
        );
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_update_bank_convert_out_fee(_player_id character varying, _guild_id character varying, _fee character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _guild_id,
            2,
            'structs',
            'guild-update-bank-convert-out-fee',
            jsonb_build_array(_guild_id, _fee),
            '{}'
        );
    END
    $function$
;
DROP FUNCTION signer.GUILD_TOKEN_COIN_ARGUMENT(NUMERIC,CHARACTER VARYING);
DROP FUNCTION signer.BANK_GUILD(CHARACTER VARYING);
DROP FUNCTION signer.BANK_FEE_ARGUMENT(CHARACTER VARYING);
COMMIT;
