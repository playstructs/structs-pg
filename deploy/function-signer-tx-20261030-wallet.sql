-- Deploy structs-pg:function-signer-tx-20261030-wallet to pg
BEGIN;
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'wallet wrappers require the coordinated v022-1 signer contract';
    END IF;
END $$;

-- Only Alpha has an established display-unit alias here. All other denoms are
-- exact bank denominations; never prefix an arbitrary denom or guess its scale.
CREATE FUNCTION signer.WALLET_COIN_ARGUMENT(_amount NUMERIC,_denom CHARACTER VARYING,_alpha_only BOOLEAN DEFAULT FALSE)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $BODY$
BEGIN
    IF _denom='alpha' THEN
        RETURN signer.COIN_ARGUMENT(_amount * 1000000,'ualpha');
    END IF;
    IF _alpha_only AND _denom IS DISTINCT FROM 'ualpha' THEN
        RAISE EXCEPTION 'reactor and generator fuel must be Alpha' USING ERRCODE='22023';
    END IF;
    RETURN signer.COIN_ARGUMENT(_amount,_denom);
END
$BODY$;

CREATE FUNCTION signer.VAULT_ADDRESS(_owner_id CHARACTER VARYING)
RETURNS CHARACTER VARYING LANGUAGE plpgsql STABLE AS $BODY$
DECLARE _address CHARACTER VARYING;
BEGIN
    SELECT address INTO _address FROM structs.asset_owner WHERE owner_id=_owner_id AND is_vault;
    IF _address IS NULL THEN
        RAISE EXCEPTION 'owner vault is not indexed: %',_owner_id USING ERRCODE='55000';
    END IF;
    RETURN _address;
END
$BODY$;

CREATE FUNCTION signer.REACTOR_SOURCE(_player_id CHARACTER VARYING,_delegator_address CHARACTER VARYING,
    _owner_id CHARACTER VARYING,_permission INTEGER)
RETURNS JSONB LANGUAGE plpgsql STABLE AS $BODY$
DECLARE _selected CHARACTER VARYING;
BEGIN
    IF NULLIF(_delegator_address,'') IS NULL OR NULLIF(_owner_id,'') IS NOT NULL THEN
        _selected := signer.SELECT_ASSET_OWNER(_player_id,_owner_id);
        IF NULLIF(_delegator_address,'') IS NOT NULL
            AND _delegator_address<>signer.VAULT_ADDRESS(_selected) THEN
            RAISE EXCEPTION 'delegator does not match the selected owner vault' USING ERRCODE='22023';
        END IF;
        -- Owner routing can provision an empty vault on chain. Do not require
        -- an indexed vault row when no explicit address must be compared.
        RETURN jsonb_build_object('flags',jsonb_build_object('owner-id',_selected),
            'checks',jsonb_build_array(jsonb_build_object('check_type','object','object_id',_selected,'permission',_permission)));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM structs.asset_owner WHERE address=_delegator_address) THEN
        RAISE EXCEPTION 'delegator has no current indexed asset owner' USING ERRCODE='22023';
    END IF;
    RETURN jsonb_build_object('flags',jsonb_build_object('delegator-address',_delegator_address),
        'checks',jsonb_build_array(jsonb_build_object('check_type','address-owner','object_id',_delegator_address,'permission',_permission)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_infuse(_player_id CHARACTER VARYING,_delegator_address CHARACTER VARYING,
    _destination CHARACTER VARYING,_amount NUMERIC,_denom CHARACTER VARYING,_owner_id CHARACTER VARYING)
RETURNS void AS $BODY$
DECLARE _coin TEXT; _destination_address CHARACTER VARYING; _source JSONB;
BEGIN
    _coin := signer.WALLET_COIN_ARGUMENT(_amount,_denom,TRUE);
    IF _destination ~ '^0-[1-9][0-9]*$' THEN
        SELECT r.validator INTO _destination_address FROM structs.guild g
            JOIN structs.reactor r ON r.id=g.primary_reactor_id WHERE g.id=_destination;
    ELSIF _destination ~ '^3-[1-9][0-9]*$' THEN
        SELECT validator INTO _destination_address FROM structs.reactor WHERE id=_destination;
    ELSIF _destination ~ '^5-[1-9][0-9]*$' THEN
        -- This message always burns from the acting player's vault. Never
        -- silently ignore an explicit retained or guild source.
        IF (NULLIF(_owner_id,'') IS NOT NULL AND _owner_id<>_player_id)
            OR (NULLIF(_delegator_address,'') IS NOT NULL
                AND _delegator_address<>signer.VAULT_ADDRESS(_player_id)) THEN
            RAISE EXCEPTION 'generator infusion only supports the acting player vault' USING ERRCODE='22023';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM structs.struct WHERE id=_destination AND NOT is_destroyed) THEN
            RAISE EXCEPTION 'generator struct does not exist or is destroyed' USING ERRCODE='22023';
        END IF;
        PERFORM signer.UINT64_ARGUMENT(left(_coin,length(_coin)-6)::numeric,'generator fuel',FALSE);
        PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','struct-generator-infuse',
            jsonb_build_array(_destination,_coin),'{}'::jsonb,
            jsonb_build_array(jsonb_build_object('check_type','object','object_id',_player_id,'permission',32)));
        RETURN;
    ELSIF _destination LIKE 'structsvaloper1%' THEN
        _destination_address := _destination;
    END IF;
    IF _destination_address IS NULL OR _destination_address NOT LIKE 'structsvaloper1%' THEN
        RAISE EXCEPTION 'infusion destination does not resolve to a reactor' USING ERRCODE='22023';
    END IF;
    _source := signer.REACTOR_SOURCE(_player_id,_delegator_address,_owner_id,32);
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','reactor-infuse',
        jsonb_build_array(_destination_address,_coin),_source->'flags',_source->'checks');
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_infuse(_player_id CHARACTER VARYING,_delegator_address CHARACTER VARYING,
    _destination CHARACTER VARYING,_amount NUMERIC,_denom CHARACTER VARYING)
RETURNS void AS $BODY$
BEGIN
    PERFORM signer.tx_infuse(_player_id,_delegator_address,_destination,_amount,_denom,NULL);
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_infuse(_player_id CHARACTER VARYING,_destination CHARACTER VARYING,
    _amount NUMERIC,_denom CHARACTER VARYING)
RETURNS void AS $BODY$
BEGIN
    PERFORM signer.tx_infuse(_player_id,NULL,_destination,_amount,_denom,NULL);
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_reactor_defuse(_player_id CHARACTER VARYING,_delegator_address CHARACTER VARYING,
    _validator_address CHARACTER VARYING,_amount NUMERIC,_denom CHARACTER VARYING,_owner_id CHARACTER VARYING)
RETURNS void AS $BODY$
DECLARE _source JSONB;
BEGIN
    _source := signer.REACTOR_SOURCE(_player_id,_delegator_address,_owner_id,128);
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','reactor-defuse',
        jsonb_build_array(_validator_address,signer.WALLET_COIN_ARGUMENT(_amount,_denom,TRUE)),_source->'flags',_source->'checks');
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_reactor_defuse(_player_id CHARACTER VARYING,_delegator_address CHARACTER VARYING,
    _validator_address CHARACTER VARYING,_amount NUMERIC,_denom CHARACTER VARYING)
RETURNS void AS $BODY$
BEGIN
    PERFORM signer.tx_reactor_defuse(_player_id,_delegator_address,_validator_address,_amount,_denom,NULL);
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_reactor_begin_migration(_player_id CHARACTER VARYING,_delegator_address CHARACTER VARYING,
    _validator_src_address CHARACTER VARYING,_validator_dst_address CHARACTER VARYING,_amount NUMERIC,
    _denom CHARACTER VARYING,_owner_id CHARACTER VARYING)
RETURNS void AS $BODY$
DECLARE _source JSONB;
BEGIN
    _source := signer.REACTOR_SOURCE(_player_id,_delegator_address,_owner_id,64);
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','reactor-begin-migration',
        jsonb_build_array(_validator_src_address,_validator_dst_address,signer.WALLET_COIN_ARGUMENT(_amount,_denom,TRUE)),
        _source->'flags',_source->'checks');
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_reactor_begin_migration(_player_id CHARACTER VARYING,_delegator_address CHARACTER VARYING,
    _validator_src_address CHARACTER VARYING,_validator_dst_address CHARACTER VARYING,_amount NUMERIC,_denom CHARACTER VARYING)
RETURNS void AS $BODY$
BEGIN
    PERFORM signer.tx_reactor_begin_migration(_player_id,_delegator_address,_validator_src_address,_validator_dst_address,_amount,_denom,NULL);
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

-- Widen the existing height identity instead of leaving ambiguous integer /
-- numeric overloads. Retain its privileges before replacing the signature.
CREATE TEMP TABLE signer_wallet_height_acl ON COMMIT DROP AS
    SELECT proowner,proacl FROM pg_proc WHERE oid='signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,integer)'::regprocedure;
DROP FUNCTION signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,integer);

CREATE OR REPLACE FUNCTION signer.tx_reactor_cancel_defusion(_player_id CHARACTER VARYING,_delegator_address CHARACTER VARYING,
    _validator_address CHARACTER VARYING,_amount NUMERIC,_denom CHARACTER VARYING,_creation_height NUMERIC,_owner_id CHARACTER VARYING)
RETURNS void AS $BODY$
DECLARE _source JSONB;
BEGIN
    IF _creation_height>9223372036854775807 THEN
        RAISE EXCEPTION 'creation height exceeds int64' USING ERRCODE='22023';
    END IF;
    _source := signer.REACTOR_SOURCE(_player_id,_delegator_address,_owner_id,32);
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','reactor-cancel-defusion',
        jsonb_build_array(_validator_address,signer.WALLET_COIN_ARGUMENT(_amount,_denom,TRUE),
            signer.UINT64_ARGUMENT(_creation_height,'creation height',FALSE)),_source->'flags',_source->'checks');
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_reactor_cancel_defusion(_player_id CHARACTER VARYING,_delegator_address CHARACTER VARYING,
    _validator_address CHARACTER VARYING,_amount NUMERIC,_denom CHARACTER VARYING,_creation_height NUMERIC)
RETURNS void AS $BODY$
BEGIN
    PERFORM signer.tx_reactor_cancel_defusion(_player_id,_delegator_address,_validator_address,_amount,_denom,_creation_height,NULL);
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_player_send(_player_id CHARACTER VARYING,_from_address CHARACTER VARYING,
    _to_address CHARACTER VARYING,_amount NUMERIC,_denom CHARACTER VARYING)
RETURNS void AS $BODY$
DECLARE _source CHARACTER VARYING;
BEGIN
    _source := COALESCE(NULLIF(_from_address,''),signer.VAULT_ADDRESS(_player_id));
    IF NULLIF(_to_address,'') IS NULL OR NOT EXISTS (SELECT 1 FROM structs.asset_owner WHERE address=_source) THEN
        RAISE EXCEPTION 'transfer requires a recipient and a current asset source' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','player-send',
        jsonb_build_array(_source,_to_address,signer.WALLET_COIN_ARGUMENT(_amount,_denom)),
        '{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','address-owner','object_id',_source,'permission',16)));
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_bank_send(_player_id CHARACTER VARYING,_amount NUMERIC,
    _denom CHARACTER VARYING,_destination_player_id CHARACTER VARYING)
RETURNS void AS $BODY$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM structs.player WHERE id=_destination_player_id) THEN
        RAISE EXCEPTION 'recipient player does not exist' USING ERRCODE='22023';
    END IF;
    -- Historical name retained for callers; vault movement uses PlayerSend,
    -- authorized by an ordinary key rather than a vault signature.
    PERFORM signer.tx_player_send(_player_id,signer.VAULT_ADDRESS(_player_id),
        signer.VAULT_ADDRESS(_destination_player_id),_amount,_denom);
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_guild_create(_player_id CHARACTER VARYING,_reactor_id CHARACTER VARYING,
    _endpoint CHARACTER VARYING,_entry_substation_id CHARACTER VARYING)
RETURNS void AS $BODY$
DECLARE _checks JSONB;
BEGIN
    _checks := jsonb_build_array(jsonb_build_object('check_type','object','object_id',_player_id,'permission',17));
    IF NULLIF(_entry_substation_id,'') IS NOT NULL THEN
        _checks := _checks || jsonb_build_array(jsonb_build_object('check_type','object','object_id',_entry_substation_id,'permission',1024));
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','guild-create',
        jsonb_build_array(_reactor_id,COALESCE(_endpoint,''),COALESCE(_entry_substation_id,'')),
        '{}'::jsonb,_checks);
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_guild_create_charter(_player_id CHARACTER VARYING,_reactor_id CHARACTER VARYING,
    _endpoint CHARACTER VARYING,_entry_substation_id CHARACTER VARYING,_proof CHARACTER VARYING,_nonce CHARACTER VARYING,
    _founder_player_id CHARACTER VARYING DEFAULT NULL,_address CHARACTER VARYING DEFAULT NULL,
    _proof_pub_key CHARACTER VARYING DEFAULT NULL,_proof_signature CHARACTER VARYING DEFAULT NULL)
RETURNS void AS $BODY$
BEGIN
    -- Do not turn a retired free/third-party charter request into a paid spend.
    RAISE EXCEPTION 'legacy charter authorization is not supported; use tx_guild_create for paid creation' USING ERRCODE='22023';
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

DO $$
DECLARE f RECORD; a RECORD; target REGPROCEDURE; grantee_name TEXT;
BEGIN
    FOR f IN SELECT p.proowner,p.proacl,v.target
        FROM (VALUES
            ('signer.tx_infuse(character varying,character varying,character varying,numeric,character varying)','signer.tx_infuse(character varying,character varying,character varying,numeric,character varying,character varying)'),
            ('signer.tx_reactor_defuse(character varying,character varying,character varying,numeric,character varying)','signer.tx_reactor_defuse(character varying,character varying,character varying,numeric,character varying,character varying)'),
            ('signer.tx_reactor_begin_migration(character varying,character varying,character varying,character varying,numeric,character varying)','signer.tx_reactor_begin_migration(character varying,character varying,character varying,character varying,numeric,character varying,character varying)'),
            ('signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,integer)','signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,numeric,character varying)'),
            ('signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,integer)','signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,numeric)')
        ) v(source,target) JOIN LATERAL (
            SELECT proowner,proacl FROM pg_temp.signer_wallet_height_acl WHERE v.source='signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,integer)'
            UNION ALL SELECT proowner,proacl FROM pg_proc WHERE oid=to_regprocedure(v.source)
                AND v.source<>'signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,integer)'
        ) p ON TRUE
    LOOP
        target := f.target::regprocedure;
        EXECUTE format('ALTER FUNCTION %s OWNER TO %I',target,pg_get_userbyid(f.proowner));
        -- Clear defaults too: an installation may have ALTER DEFAULT
        -- PRIVILEGES grants that the existing overload deliberately revoked.
        FOR a IN SELECT acl.* FROM pg_proc p,
            LATERAL aclexplode(COALESCE(p.proacl,acldefault('f',p.proowner))) acl WHERE p.oid=target LOOP
            grantee_name := CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(a.grantee)) END;
            EXECUTE format('REVOKE ALL ON FUNCTION %s FROM %s',target,grantee_name);
        END LOOP;
        FOR a IN SELECT * FROM aclexplode(COALESCE(f.proacl,acldefault('f',f.proowner))) LOOP
            grantee_name := CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(a.grantee)) END;
            EXECUTE format('GRANT %s ON FUNCTION %s TO %s%s',a.privilege_type,target,grantee_name,
                CASE WHEN a.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
        END LOOP;
    END LOOP;
END $$;
COMMIT;
