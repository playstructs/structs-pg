-- Deploy structs-pg:function-signer-tx-20261030-guild-bank to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'guild-bank wrappers require the coordinated v022-1 signer contract';
    END IF;
END $$;

CREATE FUNCTION signer.BANK_GUILD(_guild_id CHARACTER VARYING)
RETURNS CHARACTER VARYING LANGUAGE plpgsql STABLE AS $BODY$
BEGIN
    IF _guild_id IS NULL OR _guild_id !~ '^0-[1-9][0-9]*$'
        OR NOT EXISTS (SELECT 1 FROM structs.guild WHERE id=_guild_id) THEN
        RAISE EXCEPTION 'guild bank does not exist' USING ERRCODE='22023';
    END IF;
    PERFORM signer.UINT64_ARGUMENT(substring(_guild_id from 3)::numeric,'guild id',FALSE);
    RETURN _guild_id;
END
$BODY$;

CREATE FUNCTION signer.GUILD_TOKEN_COIN_ARGUMENT(_amount NUMERIC,_denom CHARACTER VARYING)
RETURNS TEXT LANGUAGE plpgsql STABLE AS $BODY$
BEGIN
    -- Guild-bank methods accept only their exact native bank denomination.
    -- An arbitrary leading u says nothing about denomination units or issuer.
    IF _denom IS NULL OR _denom !~ '^uguild\.0-[1-9][0-9]*$' THEN
        RAISE EXCEPTION 'guild bank requires an exact uguild.0-N denomination' USING ERRCODE='22023';
    END IF;
    PERFORM signer.BANK_GUILD(substring(_denom from 8));
    RETURN signer.UINT64_ARGUMENT(_amount,'guild token amount',FALSE) || _denom;
END
$BODY$;

CREATE FUNCTION signer.BANK_FEE_ARGUMENT(_fee CHARACTER VARYING)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $BODY$
BEGIN
    IF _fee IS NULL OR _fee !~ '^[0-9]+(\.[0-9]{1,18})?$' THEN
        RAISE EXCEPTION 'guild bank fee must be a decimal with at most 18 places' USING ERRCODE='22023';
    END IF;
    IF _fee::numeric>=1 THEN
        RAISE EXCEPTION 'guild bank fee must be in [0,1)' USING ERRCODE='22023';
    END IF;
    RETURN trim_scale(_fee::numeric)::text;
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_bank_mint(_player_id CHARACTER VARYING,_amount_alpha NUMERIC,
    _amount_token NUMERIC,_guild_id CHARACTER VARYING)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
DECLARE _selected CHARACTER VARYING;
BEGIN
    _selected := signer.BANK_GUILD(COALESCE(NULLIF(_guild_id,''),(SELECT guild_id FROM structs.player WHERE id=_player_id)));
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_selected,'structs','guild-bank-mint',
        jsonb_build_array(signer.UINT64_ARGUMENT(_amount_alpha,'alpha collateral',FALSE),
            signer.UINT64_ARGUMENT(_amount_token,'guild issuance',FALSE)),jsonb_build_object('guild-id',_selected),
        jsonb_build_array(jsonb_build_object('check_type','object','object_id',_player_id,'permission',16),
            jsonb_build_object('check_type','object','object_id',_selected,'permission',8192),
            jsonb_build_object('check_type','object','object_id',_selected,'permission',16)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_bank_confiscate_and_burn(_player_id CHARACTER VARYING,_amount_token NUMERIC,
    _address CHARACTER VARYING,_guild_id CHARACTER VARYING)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
DECLARE _selected CHARACTER VARYING;
BEGIN
    _selected := signer.BANK_GUILD(COALESCE(NULLIF(_guild_id,''),(SELECT guild_id FROM structs.player WHERE id=_player_id)));
    IF _address IS NULL OR _address !~ '^structs1[ac-hj-np-z02-9]{38}$' THEN
        RAISE EXCEPTION 'confiscation requires an exact account address' USING ERRCODE='22023';
    END IF;
    -- The address is a subject, not an additional signer. Holder and checksum
    -- validity remain chain checks; no grant to spend its other assets is added.
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_selected,'structs','guild-bank-confiscate-and-burn',
        jsonb_build_array(signer.UINT64_ARGUMENT(_amount_token,'guild burn amount',FALSE),_address),
        jsonb_build_object('guild-id',_selected),
        jsonb_build_array(jsonb_build_object('check_type','object','object_id',_selected,'permission',4096)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_bank_convert(_player_id CHARACTER VARYING,_guild_id CHARACTER VARYING,
    _amount_alpha NUMERIC,_min_amount_token NUMERIC)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','guild-bank-convert',
        jsonb_build_array(signer.BANK_GUILD(_guild_id),signer.UINT64_ARGUMENT(_amount_alpha,'alpha amount',FALSE),
            signer.UINT64_ARGUMENT(_min_amount_token,'minimum token output',FALSE)),'{}'::jsonb,
        jsonb_build_array(jsonb_build_object('check_type','object','object_id',_player_id,'permission',16)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_bank_redeem(_player_id CHARACTER VARYING,_amount NUMERIC,
    _denom CHARACTER VARYING,_min_amount_alpha NUMERIC)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','guild-bank-redeem',
        jsonb_build_array(signer.GUILD_TOKEN_COIN_ARGUMENT(_amount,_denom),
            signer.UINT64_ARGUMENT(_min_amount_alpha,'minimum alpha output',FALSE)),'{}'::jsonb,
        jsonb_build_array(jsonb_build_object('check_type','object','object_id',_player_id,'permission',16)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_bank_convert_token(_player_id CHARACTER VARYING,_amount_token NUMERIC,
    _denom CHARACTER VARYING,_target_guild_id CHARACTER VARYING,_min_amount_token NUMERIC)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
DECLARE _coin TEXT; _target CHARACTER VARYING;
BEGIN
    _coin := signer.GUILD_TOKEN_COIN_ARGUMENT(_amount_token,_denom);
    _target := signer.BANK_GUILD(_target_guild_id);
    IF substring(_denom from 8)=_target THEN
        RAISE EXCEPTION 'source and target guild must differ' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','guild-bank-convert-token',
        jsonb_build_array(_coin,_target,signer.UINT64_ARGUMENT(_min_amount_token,'minimum token output',FALSE)),
        '{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_player_id,'permission',16)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_update_bank_convert_in_fee(_player_id CHARACTER VARYING,
    _guild_id CHARACTER VARYING,_fee CHARACTER VARYING)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_guild_id,'structs','guild-update-bank-convert-in-fee',
        jsonb_build_array(signer.BANK_GUILD(_guild_id),signer.BANK_FEE_ARGUMENT(_fee)),'{}'::jsonb,
        jsonb_build_array(jsonb_build_object('check_type','object','object_id',_guild_id,'permission',2)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_update_bank_convert_out_fee(_player_id CHARACTER VARYING,
    _guild_id CHARACTER VARYING,_fee CHARACTER VARYING)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_guild_id,'structs','guild-update-bank-convert-out-fee',
        jsonb_build_array(signer.BANK_GUILD(_guild_id),signer.BANK_FEE_ARGUMENT(_fee)),'{}'::jsonb,
        jsonb_build_array(jsonb_build_object('check_type','object','object_id',_guild_id,'permission',2)));
END
$BODY$;
COMMIT;
