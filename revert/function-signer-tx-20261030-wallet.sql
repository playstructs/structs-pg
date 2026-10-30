-- Revert structs-pg:function-signer-tx-20261030-wallet from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.tx IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract='v022-1' AND command IN
        ('reactor-infuse','reactor-defuse','reactor-begin-migration','reactor-cancel-defusion',
         'struct-generator-infuse','player-send','guild-create')) THEN
        RAISE EXCEPTION 'versioned wallet requests exist; retain their contract or restore a verified checkpoint';
    END IF;
END $$;
CREATE TEMP TABLE signer_wallet_height_acl ON COMMIT DROP AS
    SELECT proowner,proacl FROM pg_proc WHERE oid='signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,numeric)'::regprocedure;
CREATE OR REPLACE FUNCTION signer.tx_bank_send(_player_id character varying, _amount numeric, _denom character varying, _destination_player_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    DECLARE
        _primary_address_sender CHARACTER VARYING;
        _primary_address_recipient CHARACTER VARYING;

        _real_denom CHARACTER VARYING;
        _real_amount NUMERIC;
    BEGIN

        SELECT player.primary_address INTO _primary_address_sender FROM structs.player where player.id = _player_id;
        SELECT player.primary_address INTO _primary_address_recipient FROM structs.player where player.id = _destination_player_id;

        IF _denom ILIKE 'u%' THEN
            _real_denom := _denom;
            _real_amount := _amount;
        ELSE
            _real_denom := 'u' || _denom;
            _real_amount := _amount * 10^6;
        END IF;

        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'bank','send',jsonb_build_array(_primary_address_sender,_primary_address_recipient, _real_amount || _real_denom),'{}');
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_guild_create(_player_id character varying, _reactor_id character varying, _endpoint character varying, _entry_substation_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_reactor_id,524288,'structs','guild-create',jsonb_build_array(_reactor_id, _endpoint, _entry_substation_id),'{}');
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_guild_create_charter(_player_id character varying, _reactor_id character varying, _endpoint character varying, _entry_substation_id character varying, _proof character varying, _nonce character varying, _founder_player_id character varying DEFAULT NULL::character varying, _address character varying DEFAULT NULL::character varying, _proof_pub_key character varying DEFAULT NULL::character varying, _proof_signature character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    DECLARE
        _flags JSONB;
    BEGIN
        _flags := jsonb_build_object('proof', _proof, 'nonce', _nonce);
        IF _founder_player_id IS NOT NULL AND _founder_player_id <> '' THEN
            _flags := _flags || jsonb_build_object('founder-player-id', _founder_player_id);
        END IF;
        IF _address IS NOT NULL AND _address <> '' THEN
            _flags := _flags || jsonb_build_object('address', _address);
        END IF;
        IF _proof_pub_key IS NOT NULL AND _proof_pub_key <> '' THEN
            _flags := _flags || jsonb_build_object('proof-pub-key', _proof_pub_key);
        END IF;
        IF _proof_signature IS NOT NULL AND _proof_signature <> '' THEN
            _flags := _flags || jsonb_build_object('proof-signature', _proof_signature);
        END IF;

        PERFORM signer.CREATE_TRANSACTION(
            _reactor_id,
            524288,
            'structs',
            'guild-create',
            jsonb_build_array(_reactor_id, _endpoint, _entry_substation_id),
            _flags
        );
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_infuse(_player_id character varying, _delegator_address character varying, _destination character varying, _amount numeric, _denom character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    DECLARE
        _real_denom CHARACTER VARYING;
        _real_amount NUMERIC;

        _real_destination CHARACTER VARYING;
    BEGIN

        IF _denom = 'ualpha' THEN
            _real_denom := _denom;
            _real_amount := _amount;
        ELSIF _denom = 'alpha' THEN
            _real_denom := 'u' || _denom;
            _real_amount := _amount * 10^6;
        ELSE
            RETURN;
        END IF;

        IF _destination ILIKE '0-%' THEN
            SELECT reactor.validator INTO _real_destination FROM structs.reactor WHERE reactor.id IN (SELECT guild.primary_reactor_id FROM structs.guild WHERE guild.id = _destination);
        ELSIF _destination ILIKE '3-%' THEN
            SELECT reactor.validator INTO _real_destination FROM structs.reactor WHERE reactor.id = _destination;
        ELSIF _destination ILIKE '5-%' THEN
            _real_destination := _destination;
        ELSIF _destination ILIKE 'structsvaloper%' THEN
            _real_destination := _destination;
        ELSE
            RETURN;
        END IF;

        IF _real_destination ILIKE 'structsvaloper%' THEN
            PERFORM signer.CREATE_TRANSACTION(_player_id,32,'structs','reactor-infuse',jsonb_build_array(_delegator_address, _real_destination, _real_amount || _real_denom),'{}');
        ELSIF _real_destination ILIKE '5-%' THEN
            PERFORM signer.CREATE_TRANSACTION(_player_id,32,'structs','struct-generator-infuse',jsonb_build_array(_real_destination, _real_amount || _real_denom),'{}');
        END IF;

        RETURN;
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_infuse(_player_id character varying, _destination character varying, _amount numeric, _denom character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    DECLARE
        _real_denom CHARACTER VARYING;
        _real_amount NUMERIC;

        _real_destination CHARACTER VARYING;
    BEGIN

        IF _denom = 'ualpha' THEN
            _real_denom := _denom;
            _real_amount := _amount;
        ELSIF _denom = 'alpha' THEN
            _real_denom := 'u' || _denom;
            _real_amount := _amount * 10^6;
        ELSE
            -- Not an acceptable denom
            RETURN;
        END IF;


        -- guild   = 0;
        -- reactor = 3;
        -- struct  = 5;
        -- structsvaloper

        -- Guild ID
            -- Lookup Reactor ID
        IF _destination ILIKE '0-%' THEN
            SELECT reactor.validator INTO _real_destination FROM structs.reactor WHERE reactor.id IN (SELECT guild.primary_reactor_id FROM structs.guild WHERE guild.id = _destination);

        -- Reactor ID
        ELSIF _destination ILIKE '3-%' THEN
            SELECT reactor.validator INTO _real_destination FROM structs.reactor WHERE reactor.id = _destination;

        -- Struct ID
        ELSIF _destination ILIKE '5-%' THEN
            -- TODO Make sure it's a generator
            _real_destination := _destination;

        -- Reactor
        ELSIF _destination ILIKE 'structsvaloper%' THEN
            _real_destination := _destination;
        ELSE
            RETURN;
        END IF;

        IF _real_destination ILIKE 'structsvaloper%' THEN
            PERFORM signer.CREATE_TRANSACTION(_player_id,8,'staking','delegate',jsonb_build_array(_real_destination, _real_amount || _real_denom),'{}');
        ELSIF _real_destination ILIKE '5-%' THEN
            PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','struct-generator-infuse ',jsonb_build_array(_real_destination, _real_amount || _real_denom),'{}');
        END IF;

        RETURN;
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_player_send(_player_id character varying, _from_address character varying, _to_address character varying, _amount numeric, _denom character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    DECLARE
        _real_denom CHARACTER VARYING;
        _real_amount NUMERIC;
    BEGIN
        IF _denom ILIKE 'u%' THEN
            _real_denom := _denom;
            _real_amount := _amount;
        ELSE
            _real_denom := 'u' || _denom;
            _real_amount := _amount * 10^6;
        END IF;

        PERFORM signer.CREATE_TRANSACTION(_player_id,16,'structs','player-send',jsonb_build_array(_from_address, _to_address, _real_amount || _real_denom),'{}');
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_reactor_begin_migration(_player_id character varying, _delegator_address character varying, _validator_src_address character varying, _validator_dst_address character varying, _amount numeric, _denom character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    DECLARE
        _real_denom CHARACTER VARYING;
        _real_amount NUMERIC;
    BEGIN
        IF _denom ILIKE 'u%' THEN
            _real_denom := _denom;
            _real_amount := _amount;
        ELSE
            _real_denom := 'u' || _denom;
            _real_amount := _amount * 10^6;
        END IF;
        PERFORM signer.CREATE_TRANSACTION(_player_id,64,'structs','reactor-begin-migration',jsonb_build_array( _delegator_address, _validator_src_address, _validator_dst_address, _real_amount || _real_denom),'{}');
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_reactor_cancel_defusion(_player_id character varying, _delegator_address character varying, _validator_address character varying, _amount numeric, _denom character varying, _creation_height integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    DECLARE
        _real_denom CHARACTER VARYING;
        _real_amount NUMERIC;
    BEGIN
        IF _denom ILIKE 'u%' THEN
            _real_denom := _denom;
            _real_amount := _amount;
        ELSE
            _real_denom := 'u' || _denom;
            _real_amount := _amount * 10^6;
        END IF;
        PERFORM signer.CREATE_TRANSACTION(_player_id,128,'structs','reactor-cancel-defusion',jsonb_build_array( _delegator_address, _validator_address, _real_amount || _real_denom, _creation_height),'{}');
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_reactor_defuse(_player_id character varying, _delegator_address character varying, _validator_address character varying, _amount numeric, _denom character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    DECLARE
        _real_denom CHARACTER VARYING;
        _real_amount NUMERIC;
    BEGIN
        IF _denom ILIKE 'u%' THEN
            _real_denom := _denom;
            _real_amount := _amount;
        ELSE
            _real_denom := 'u' || _denom;
            _real_amount := _amount * 10^6;
        END IF;
        PERFORM signer.CREATE_TRANSACTION(_player_id,128,'structs','reactor-defuse',jsonb_build_array( _delegator_address, _validator_address, _real_amount || _real_denom),'{}');
    END
    $function$
;
DO $$
DECLARE f RECORD; a RECORD; target REGPROCEDURE; grantee_name TEXT;
BEGIN
    FOR f IN SELECT proowner,proacl,'signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,integer)' AS target FROM pg_temp.signer_wallet_height_acl
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
DROP FUNCTION signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,numeric);
DROP FUNCTION signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,numeric,character varying);
DROP FUNCTION signer.tx_reactor_begin_migration(character varying,character varying,character varying,character varying,numeric,character varying,character varying);
DROP FUNCTION signer.tx_reactor_defuse(character varying,character varying,character varying,numeric,character varying,character varying);
DROP FUNCTION signer.tx_infuse(character varying,character varying,character varying,numeric,character varying,character varying);
DROP FUNCTION signer.REACTOR_SOURCE(character varying,character varying,character varying,integer);
DROP FUNCTION signer.VAULT_ADDRESS(character varying);
DROP FUNCTION signer.WALLET_COIN_ARGUMENT(numeric,character varying,boolean);
COMMIT;
