-- Deploy structs-pg:function-signer-tx-20261030-provider-agreement to pg
-- Protocol-sensitive wrapper activation: coordinate with the v0.22 TSA worker.
BEGIN;
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'provider/agreement wrappers require the coordinated v022-1 signer contract';
    END IF;
END $$;

CREATE FUNCTION signer.UINT64_ARGUMENT(_value NUMERIC,_name TEXT,_allow_zero BOOLEAN DEFAULT TRUE)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $BODY$
BEGIN
    IF _value IS NULL OR _allow_zero IS NULL OR NOT (_value BETWEEN 0 AND 18446744073709551615
        AND _value=trunc(_value)) OR (NOT _allow_zero AND _value=0) THEN
        RAISE EXCEPTION 'invalid uint64 argument: %',_name USING ERRCODE='22023';
    END IF;
    RETURN trunc(_value)::TEXT;
END
$BODY$;
CREATE FUNCTION signer.COIN_ARGUMENT(_amount NUMERIC,_denom CHARACTER VARYING,_allow_zero BOOLEAN DEFAULT FALSE)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $BODY$
BEGIN
    IF _amount IS NULL OR _allow_zero IS NULL OR NOT (_amount BETWEEN 0 AND
        115792089237316195423570985008687907853269984665640564039457584007913129639935
        AND _amount=trunc(_amount)) OR (NOT _allow_zero AND _amount=0)
        OR _denom IS NULL OR _denom !~ '^[a-zA-Z][a-zA-Z0-9/:._-]{2,127}$' THEN
        RAISE EXCEPTION 'invalid exact coin amount or denomination' USING ERRCODE='22023';
    END IF;
    RETURN trunc(_amount)::TEXT || _denom;
END
$BODY$;
CREATE FUNCTION signer.PENALTY_ARGUMENT(_value NUMERIC)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $BODY$
BEGIN
    IF _value IS NULL OR NOT (_value BETWEEN 0 AND 1 AND _value=trunc(_value,18)) THEN
        RAISE EXCEPTION 'penalty must be between zero and one with at most 18 decimal places' USING ERRCODE='22023';
    END IF;
    RETURN trim_scale(_value)::TEXT;
END
$BODY$;
CREATE FUNCTION signer.SELECT_ASSET_OWNER(_player_id CHARACTER VARYING,_owner_id CHARACTER VARYING)
RETURNS CHARACTER VARYING LANGUAGE plpgsql STABLE AS $BODY$
DECLARE _selected CHARACTER VARYING := COALESCE(NULLIF(_owner_id,''),_player_id);
BEGIN
    IF _selected IS NULL OR NOT (
        EXISTS (SELECT 1 FROM structs.player WHERE id=_selected)
        OR EXISTS (SELECT 1 FROM structs.guild WHERE id=_selected)) THEN
        RAISE EXCEPTION 'asset owner does not exist' USING ERRCODE='22023';
    END IF;
    RETURN _selected;
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_provider_create(_player_id CHARACTER VARYING,_substation_id CHARACTER VARYING,_rate_denom CHARACTER VARYING,_rate_amount NUMERIC,_access_policy CHARACTER VARYING,_provider_penalty NUMERIC,_consumer_penalty NUMERIC,_capacity_min NUMERIC,_capacity_max NUMERIC,_duration_min NUMERIC,_duration_max NUMERIC,_owner_id CHARACTER VARYING) RETURNS void AS
$BODY$
DECLARE
    _selected CHARACTER VARYING;
    _checks JSONB;
BEGIN
    _selected := signer.SELECT_ASSET_OWNER(_player_id,_owner_id);
    IF _access_policy IS NULL OR _access_policy NOT IN ('openMarket','guildMarket','closedMarket')
        OR _capacity_min>_capacity_max OR _duration_min>_duration_max THEN
        RAISE EXCEPTION 'invalid provider policy or range' USING ERRCODE='22023';
    END IF;
    _checks := jsonb_build_array(jsonb_build_object('check_type','object','object_id',_substation_id,'permission',256));
    IF split_part(_selected,'-',1)='0' THEN
        _checks := _checks || jsonb_build_array(jsonb_build_object('check_type','object','object_id',_selected,'permission',256));
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_substation_id,'structs','provider-create',
        jsonb_build_array(_substation_id,signer.COIN_ARGUMENT(_rate_amount,_rate_denom,TRUE),_access_policy,
            signer.PENALTY_ARGUMENT(_provider_penalty),signer.PENALTY_ARGUMENT(_consumer_penalty),
            signer.UINT64_ARGUMENT(_capacity_min,'capacity minimum'),signer.UINT64_ARGUMENT(_capacity_max,'capacity maximum'),
            signer.UINT64_ARGUMENT(_duration_min,'duration minimum'),signer.UINT64_ARGUMENT(_duration_max,'duration maximum')),
        jsonb_build_object('owner-id',_selected),_checks);
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_provider_create(_player_id CHARACTER VARYING,_substation_id CHARACTER VARYING,_rate_denom CHARACTER VARYING,_rate_amount NUMERIC,_access_policy CHARACTER VARYING,_provider_penalty NUMERIC,_consumer_penalty NUMERIC,_capacity_min NUMERIC,_capacity_max NUMERIC,_duration_min NUMERIC,_duration_max NUMERIC) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.tx_provider_create(_player_id,_substation_id,_rate_denom,_rate_amount,_access_policy,_provider_penalty,_consumer_penalty,_capacity_min,_capacity_max,_duration_min,_duration_max,NULL);
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_agreement_open(_player_id CHARACTER VARYING,_provider_id CHARACTER VARYING,_duration NUMERIC,_capacity NUMERIC,_owner_id CHARACTER VARYING) RETURNS void AS
$BODY$
DECLARE _selected CHARACTER VARYING;
BEGIN
    _selected := signer.SELECT_ASSET_OWNER(_player_id,_owner_id);
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_provider_id,'structs','agreement-open',jsonb_build_array(_provider_id,signer.UINT64_ARGUMENT(_duration,'duration',FALSE),signer.UINT64_ARGUMENT(_capacity,'capacity',FALSE)),jsonb_build_object('owner-id',_selected),jsonb_build_array(jsonb_build_object('check_type','provider-open','object_id',_provider_id,'permission',262144),jsonb_build_object('check_type','object','object_id',_selected,'permission',16)));
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_agreement_open(_player_id CHARACTER VARYING,_provider_id CHARACTER VARYING,_duration NUMERIC,_capacity NUMERIC) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.tx_agreement_open(_player_id,_provider_id,_duration,_capacity,NULL);
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_agreement_capacity_decrease(_player_id character varying, _agreement_id character varying, _capacity_decrease numeric) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_agreement_id,'structs','agreement-capacity-decrease',jsonb_build_array(_agreement_id,signer.UINT64_ARGUMENT(_capacity_decrease,'capacity_decrease',FALSE)),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_agreement_id,'permission',4)));
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_agreement_capacity_increase(_player_id character varying, _agreement_id character varying, _capacity_increase numeric) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_agreement_id,'structs','agreement-capacity-increase',jsonb_build_array(_agreement_id,signer.UINT64_ARGUMENT(_capacity_increase,'capacity_increase',FALSE)),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_agreement_id,'permission',4)));
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_agreement_close(_player_id character varying, _agreement_id character varying) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_agreement_id,'structs','agreement-close',jsonb_build_array(_agreement_id),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_agreement_id,'permission',4)));
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_agreement_duration_increase(_player_id character varying, _agreement_id character varying, _duration_increase numeric) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_agreement_id,'structs','agreement-duration-increase',jsonb_build_array(_agreement_id,signer.UINT64_ARGUMENT(_duration_increase,'duration_increase',FALSE)),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_agreement_id,'permission',4),jsonb_build_object('check_type','object-owner','object_id',_agreement_id,'permission',16)));
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_provider_delete(_player_id character varying, _provider_id character varying) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_provider_id,'structs','provider-delete',jsonb_build_array(_provider_id),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_provider_id,'permission',8)));
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_provider_update_access_policy(_player_id character varying, _provider_id character varying, _access_policy character varying) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_provider_id,'structs','provider-update-access-policy',jsonb_build_array(_provider_id,_access_policy),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_provider_id,'permission',4)));
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_provider_update_capacity_maximum(_player_id character varying, _provider_id character varying, _new_maximum_capacity numeric) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_provider_id,'structs','provider-update-capacity-maximum',jsonb_build_array(_provider_id,signer.UINT64_ARGUMENT(_new_maximum_capacity,'new_maximum_capacity',TRUE)),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_provider_id,'permission',4)));
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_provider_update_capacity_minimum(_player_id character varying, _provider_id character varying, _new_minimum_capacity numeric) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_provider_id,'structs','provider-update-capacity-minimum',jsonb_build_array(_provider_id,signer.UINT64_ARGUMENT(_new_minimum_capacity,'new_minimum_capacity',TRUE)),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_provider_id,'permission',4)));
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_provider_update_duration_maximum(_player_id character varying, _provider_id character varying, _new_maximum_duration numeric) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_provider_id,'structs','provider-update-duration-maximum',jsonb_build_array(_provider_id,signer.UINT64_ARGUMENT(_new_maximum_duration,'new_maximum_duration',TRUE)),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_provider_id,'permission',4)));
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_provider_update_duration_minimum(_player_id character varying, _provider_id character varying, _new_minimum_duration numeric) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_provider_id,'structs','provider-update-duration-minimum',jsonb_build_array(_provider_id,signer.UINT64_ARGUMENT(_new_minimum_duration,'new_minimum_duration',TRUE)),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_provider_id,'permission',4)));
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_provider_withdraw_balance(_player_id character varying, _provider_id character varying, _destination_address character varying) RETURNS void AS
$BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_provider_id,'structs','provider-withdraw-balance',jsonb_build_array(_provider_id,COALESCE(_destination_address,'')),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_provider_id,'permission',131072)));
END
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

DO $$
DECLARE f RECORD; a RECORD; target REGPROCEDURE; grantee_name TEXT;
BEGIN
    FOR f IN SELECT p.proowner,p.proacl,v.target
        FROM (VALUES
            ('signer.tx_agreement_open(character varying,character varying,numeric,numeric)',
             'signer.tx_agreement_open(character varying,character varying,numeric,numeric,character varying)'),
            ('signer.tx_provider_create(character varying,character varying,character varying,numeric,character varying,numeric,numeric,numeric,numeric,numeric,numeric)',
             'signer.tx_provider_create(character varying,character varying,character varying,numeric,character varying,numeric,numeric,numeric,numeric,numeric,numeric,character varying)')
        ) v(source,target) JOIN pg_proc p ON p.oid=v.source::regprocedure
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
