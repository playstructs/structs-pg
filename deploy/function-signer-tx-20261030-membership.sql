-- Deploy structs-pg:function-signer-tx-20261030-membership to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'membership wrappers require the coordinated v022-1 signer contract';
    END IF;
END $$;

-- Canonical AutoCLI arguments are also used by the claim guard. The CSV field
-- is one exact argument, including the empty-list argument; it is not JSON.
CREATE FUNCTION signer.MEMBERSHIP_ARGUMENTS(_operation TEXT,_guild_id CHARACTER VARYING,
    _target_id CHARACTER VARYING,_substation_id CHARACTER VARYING,_infusions CHARACTER VARYING[])
RETURNS JSONB LANGUAGE plpgsql IMMUTABLE AS $BODY$
DECLARE _args JSONB; _flags JSONB := '{}'::jsonb; _csv TEXT := COALESCE(array_to_string(_infusions,','),'');
BEGIN
    IF _guild_id IS NULL OR _guild_id !~ '^0-[1-9][0-9]{0,19}$'
        OR _target_id IS NULL OR _target_id !~ '^1-[1-9][0-9]{0,19}$' THEN
        RAISE EXCEPTION 'membership requires exact guild and player identities' USING ERRCODE='22023';
    END IF;
    PERFORM signer.UINT64_ARGUMENT(substring(_guild_id from 3)::numeric,'membership guild',FALSE);
    PERFORM signer.UINT64_ARGUMENT(substring(_target_id from 3)::numeric,'membership player',FALSE);
    IF NULLIF(_substation_id,'') IS NOT NULL THEN
        IF _substation_id !~ '^4-[1-9][0-9]{0,19}$' OR _operation NOT IN ('guild-membership-invite',
            'guild-membership-invite-approve','guild-membership-request','guild-membership-request-approve','guild-membership-join') THEN
            RAISE EXCEPTION 'invalid membership substation override' USING ERRCODE='22023';
        END IF;
        PERFORM signer.UINT64_ARGUMENT(substring(_substation_id from 3)::numeric,'membership substation',FALSE);
        _flags := jsonb_build_object('substation-id',_substation_id);
    END IF;
    IF COALESCE(cardinality(_infusions),0)>0 THEN
        IF _operation<>'guild-membership-join' OR array_ndims(_infusions)<>1
            OR octet_length(_csv)>1048576
            OR EXISTS (SELECT 1 FROM unnest(_infusions) id WHERE CASE
                WHEN id ~ '^3-[1-9][0-9]{0,19}-structs1[ac-hj-np-z02-9]{38}$'
                THEN split_part(id,'-',2)::numeric>18446744073709551615 ELSE TRUE END)
            OR (SELECT count(DISTINCT id) FROM unnest(_infusions) id)<>cardinality(_infusions) THEN
            RAISE EXCEPTION 'invalid, repeated or oversized membership infusion list' USING ERRCODE='22023';
        END IF;
    END IF;
    CASE _operation
        WHEN 'guild-membership-invite','guild-membership-kick',
             'guild-membership-request-approve','guild-membership-request-deny' THEN
            _args := jsonb_build_array(_target_id);
            _flags := _flags || jsonb_build_object('guild-id',_guild_id);
        WHEN 'guild-membership-invite-approve','guild-membership-invite-deny','guild-membership-request' THEN
            _args := jsonb_build_array(_guild_id);
            _flags := _flags || jsonb_build_object('player-id',_target_id);
        WHEN 'guild-membership-invite-revoke','guild-membership-request-revoke' THEN
            _args := jsonb_build_array(_guild_id,_target_id);
        WHEN 'guild-membership-join' THEN
            _args := jsonb_build_array(_guild_id,_csv);
            _flags := _flags || jsonb_build_object('player-id',_target_id);
        ELSE RAISE EXCEPTION 'unknown membership operation' USING ERRCODE='22023';
    END CASE;
    RETURN jsonb_build_object('args',_args,'flags',_flags);
END
$BODY$;

CREATE FUNCTION signer.MEMBERSHIP_STATION_ACCEPTING(_id CHARACTER VARYING)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $BODY$
    SELECT NULLIF(_id,'') IS NULL OR EXISTS (SELECT 1 FROM structs.substation WHERE id=_id AND deletion_pending IS FALSE);
$BODY$;

CREATE FUNCTION signer.MEMBERSHIP_CONTEXT_CHECK(_tx_id INTEGER,_address CHARACTER VARYING)
RETURNS BOOLEAN LANGUAGE plpgsql STABLE AS $BODY$
DECLARE
    _tx signer.tx%ROWTYPE; _actor structs.player%ROWTYPE; _target structs.player%ROWTYPE; _guild structs.guild%ROWTYPE;
    _app structs.guild_membership_application%ROWTYPE; _infusion structs.infusion%ROWTYPE; _reactor structs.reactor%ROWTYPE;
    _guild_id CHARACTER VARYING; _target_id CHARACTER VARYING; _station CHARACTER VARYING; _previous_station CHARACTER VARYING;
    _infusions CHARACTER VARYING[]; _id TEXT; _arguments JSONB; _type TEXT; _policy TEXT; _pending BOOLEAN;
BEGIN
    SELECT * INTO _tx FROM signer.tx WHERE id=_tx_id;
    IF NOT FOUND OR _tx.contract IS DISTINCT FROM 'v022-1' OR _tx.module<>'structs' THEN RETURN FALSE; END IF;
    SELECT p.* INTO _actor FROM structs.player_address pa JOIN structs.player p ON p.id=pa.player_id
        WHERE pa.address=_address AND pa.status='approved' AND pa.player_id=_tx.requested_player_id;
    IF NOT FOUND OR signer.PERMISSION_CHECK(_address,_actor.id,512) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
    _station := _tx.flags->>'substation-id';
    CASE _tx.command::text
        WHEN 'guild-membership-invite','guild-membership-kick',
             'guild-membership-request-approve','guild-membership-request-deny' THEN
            _target_id := _tx.args->>0; _guild_id := _tx.flags->>'guild-id';
        WHEN 'guild-membership-invite-approve','guild-membership-invite-deny','guild-membership-request' THEN
            _guild_id := _tx.args->>0; _target_id := _tx.flags->>'player-id';
        WHEN 'guild-membership-invite-revoke','guild-membership-request-revoke' THEN
            _guild_id := _tx.args->>0; _target_id := _tx.args->>1;
        WHEN 'guild-membership-join' THEN
            _guild_id := _tx.args->>0; _target_id := _tx.flags->>'player-id';
            _infusions := string_to_array(_tx.args->>1,',');
        ELSE RETURN FALSE;
    END CASE;
    BEGIN
        _arguments := signer.MEMBERSHIP_ARGUMENTS(_tx.command::text,_guild_id,_target_id,_station,_infusions);
    EXCEPTION WHEN invalid_parameter_value THEN RETURN FALSE; END;
    IF _tx.args IS DISTINCT FROM _arguments->'args' OR _tx.flags IS DISTINCT FROM _arguments->'flags'
        OR _tx.object_id IS DISTINCT FROM _guild_id
        OR NOT EXISTS (SELECT 1 FROM signer.tx_authority WHERE tx_id=_tx_id AND check_type='object'
            AND object_id=_actor.id AND permission=512 AND subject_id='' AND operation='') THEN RETURN FALSE; END IF;
    SELECT * INTO _guild FROM structs.guild WHERE id=_guild_id;
    IF NOT FOUND THEN RETURN FALSE; END IF;
    SELECT * INTO _target FROM structs.player WHERE id=_target_id;
    IF NOT FOUND THEN RETURN FALSE; END IF;

    IF _tx.command='guild-membership-kick' THEN
        RETURN _target.guild_id IS NOT DISTINCT FROM _guild_id AND _guild.owner IS DISTINCT FROM _target.id
            AND signer.PERMISSION_CHECK(_address,_guild_id,512) IS TRUE
            AND (_actor.guild_id IS DISTINCT FROM _guild_id OR
                (_actor.guild_rank IS NOT NULL AND _target.guild_rank IS NOT NULL AND _actor.guild_rank<_target.guild_rank));
    END IF;
    IF _target.guild_id IS NOT DISTINCT FROM _guild_id THEN RETURN FALSE; END IF;
    _type := CASE WHEN _tx.command::text LIKE 'guild-membership-invite%' THEN 'invite'
        WHEN _tx.command='guild-membership-join' THEN 'direct' ELSE 'request' END;
    -- Terminal projection rows are history, not consent: the chain clears them.
    SELECT * INTO _app FROM structs.guild_membership_application
        WHERE guild_id=_guild_id AND player_id=_target_id AND status='proposed';
    _pending := FOUND;
    IF (_pending AND _app.join_type IS DISTINCT FROM _type)
        OR (NOT _pending AND _tx.command NOT IN ('guild-membership-invite','guild-membership-request','guild-membership-join')) THEN
        RETURN FALSE;
    END IF;
    CASE _tx.command::text
        WHEN 'guild-membership-invite','guild-membership-invite-revoke' THEN _policy := _guild.join_infusion_minimum_bypass_by_invite;
        WHEN 'guild-membership-request-approve','guild-membership-request-deny' THEN _policy := _guild.join_infusion_minimum_bypass_by_request;
        ELSE
            IF signer.PERMISSION_CHECK(_address,_target_id,512) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
            IF _tx.command='guild-membership-request'
                AND COALESCE(_guild.join_infusion_minimum_bypass_by_request,'') NOT IN ('permissioned','member') THEN RETURN FALSE; END IF;
    END CASE;
    IF _tx.command IN ('guild-membership-invite','guild-membership-invite-revoke',
        'guild-membership-request-approve','guild-membership-request-deny') THEN
        CASE _policy
            WHEN 'permissioned' THEN
                IF signer.PERMISSION_CHECK(_address,_guild_id,512) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
            WHEN 'member' THEN
                IF (_actor.guild_id=_guild_id OR _guild.owner=_actor.id) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
            ELSE RETURN FALSE;
        END CASE;
    END IF;

    _previous_station := COALESCE(NULLIF(_app.substation_id,''),_guild.entry_substation_id);
    IF _tx.command='guild-membership-join'
        AND NOT signer.MEMBERSHIP_STATION_ACCEPTING(_previous_station) THEN RETURN FALSE; END IF;
    IF NULLIF(_station,'') IS NOT NULL AND _station IS DISTINCT FROM COALESCE(_app.substation_id,'') THEN
        IF NOT signer.MEMBERSHIP_STATION_ACCEPTING(_station)
            OR signer.PERMISSION_CHECK(_address,_station,1024) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
    END IF;
    IF _tx.command IN ('guild-membership-invite-approve','guild-membership-request-approve','guild-membership-join')
        AND NOT signer.MEMBERSHIP_STATION_ACCEPTING(COALESCE(NULLIF(_station,''),_previous_station)) THEN RETURN FALSE; END IF;

    IF _tx.command='guild-membership-join' THEN
        IF _guild.join_infusion_minimum_p IS NULL OR _guild.join_infusion_minimum_p NOT BETWEEN 0 AND 18446744073709551615
            OR _guild.join_infusion_minimum_p<>trunc(_guild.join_infusion_minimum_p)
            OR NOT EXISTS (SELECT 1 FROM structs.reactor WHERE id=_guild.primary_reactor_id) THEN RETURN FALSE; END IF;
        IF _guild.join_infusion_minimum_p>0 THEN
            FOREACH _id IN ARRAY COALESCE(_infusions,ARRAY[]::varchar[]) LOOP
                SELECT * INTO _infusion FROM structs.infusion
                    WHERE destination_id=split_part(_id,'-',1)||'-'||split_part(_id,'-',2) AND address=split_part(_id,'-',3);
                IF NOT FOUND OR _infusion.destination_type IS DISTINCT FROM 'reactor' OR _infusion.player_id IS DISTINCT FROM _target_id
                    OR NOT EXISTS (SELECT 1 FROM structs.asset_owner WHERE address=_infusion.address AND owner_id=_target_id) THEN RETURN FALSE; END IF;
                SELECT * INTO _reactor FROM structs.reactor WHERE id=_infusion.destination_id;
                IF NOT FOUND THEN RETURN FALSE; END IF;
                IF _reactor.guild_id IS DISTINCT FROM _guild_id AND _reactor.id IS DISTINCT FROM _guild.primary_reactor_id
                    AND signer.PERMISSION_CHECK(_address,_target_id,64) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
            END LOOP;
        END IF;
    END IF;
    RETURN TRUE;
END
$BODY$;

CREATE FUNCTION signer.CREATE_MEMBERSHIP_TRANSACTION_V022(_player_id CHARACTER VARYING,_operation structs.signer_tx_type,
    _guild_id CHARACTER VARYING,_target_id CHARACTER VARYING,_substation_id CHARACTER VARYING,_infusions CHARACTER VARYING[])
RETURNS VOID LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _selected CHARACTER VARYING; _target CHARACTER VARYING; _arguments JSONB;
BEGIN
    _selected := COALESCE(NULLIF(_guild_id,''),(SELECT guild_id FROM structs.player WHERE id=_player_id));
    IF NOT EXISTS (SELECT 1 FROM structs.guild WHERE id=_selected) THEN
        RAISE EXCEPTION 'membership guild does not exist' USING ERRCODE='22023';
    END IF;
    _target := CASE WHEN _operation IN ('guild-membership-invite','guild-membership-kick') THEN _target_id
        ELSE COALESCE(NULLIF(_target_id,''),_player_id) END;
    IF NOT EXISTS (SELECT 1 FROM structs.player WHERE id=_target) THEN
        RAISE EXCEPTION 'membership target player does not exist' USING ERRCODE='22023';
    END IF;
    _arguments := signer.MEMBERSHIP_ARGUMENTS(_operation::text,_selected,_target,_substation_id,_infusions);
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_selected,'structs',_operation,_arguments->'args',_arguments->'flags',
        jsonb_build_array(jsonb_build_object('check_type','object','object_id',_player_id,'permission',512)));
END
$BODY$;
REVOKE ALL ON FUNCTION signer.CREATE_MEMBERSHIP_TRANSACTION_V022(CHARACTER VARYING,structs.signer_tx_type,
    CHARACTER VARYING,CHARACTER VARYING,CHARACTER VARYING,CHARACTER VARYING[]) FROM PUBLIC;

-- Existing wrappers and the command-specific claim guard follow below.
CREATE OR REPLACE FUNCTION signer.authorized_accounts_v022(_tx_id integer)
 RETURNS TABLE(account_id integer, address character varying, status signer_account_status)
 LANGUAGE sql
 STABLE
AS $function$
    SELECT a.id,a.address,a.status
    FROM signer.tx t
    JOIN signer.role r ON r.player_id=t.requested_player_id AND r.status='ready'
    JOIN signer.account a ON a.role_id=r.id
    JOIN structs.player_address pa ON pa.address=a.address AND pa.status='approved'
        AND pa.player_id=t.requested_player_id
    WHERE t.id=_tx_id AND t.contract='v022-1'
      AND CASE WHEN t.command::text LIKE 'guild-membership-%'
          THEN signer.MEMBERSHIP_CONTEXT_CHECK(t.id,a.address) ELSE TRUE END
      AND (t.command<>'address-register' OR signer.REGISTRATION_CONTEXT_CHECK(t.id))
      AND (t.command NOT IN ('address-revoke','player-update-primary-address') OR signer.ADDRESS_MANAGEMENT_CHECK(t.id))
      AND EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id)
      AND NOT EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id
          AND (CASE WHEN rule.check_type IN ('permission-address','permission-object') THEN
              signer.PERMISSION_MUTATION_CHECK(a.address,rule.check_type,rule.object_id,
                  rule.subject_id,rule.operation,rule.permission)
          ELSE signer.TRANSACTION_AUTHORITY_CHECK(a.address,t.requested_player_id,
              rule.check_type,rule.object_id,rule.permission) END) IS DISTINCT FROM TRUE);
$function$
;

-- Worker-owned controls from the actual v0.22 CLI, including SDK unordered/auxiliary modes.
CREATE OR REPLACE FUNCTION signer.create_transaction_v022(_player_id character varying, _object_id character varying, _module signer_tx_module, _command signer_tx_type, _args jsonb, _flags jsonb, _checks jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    _context RECORD;
    _tx signer.tx%ROWTYPE;
BEGIN
    IF _player_id IS NULL OR NOT EXISTS (SELECT 1 FROM structs.player WHERE id=_player_id) THEN
        RAISE EXCEPTION 'requested signing player does not exist' USING ERRCODE='22023';
    END IF;
    -- Strings survive JSON/CLI transport without jq or JavaScript number loss.
    IF _args IS NULL OR jsonb_typeof(_args) <> 'array' THEN
        RAISE EXCEPTION 'transaction args must be a string array' USING ERRCODE='22023';
    END IF;
    IF jsonb_array_length(_args)>64 OR EXISTS (SELECT 1 FROM jsonb_array_elements(_args) a WHERE jsonb_typeof(a)<>'string') THEN
        RAISE EXCEPTION 'transaction args must be at most 64 exact strings' USING ERRCODE='22023';
    END IF;
    IF _flags IS NULL OR jsonb_typeof(_flags)<>'object' THEN
        RAISE EXCEPTION 'transaction flags must be a string object' USING ERRCODE='22023';
    END IF;
    IF (SELECT count(*) FROM jsonb_each(_flags))>64 OR EXISTS (
        SELECT 1 FROM jsonb_each(_flags) f WHERE jsonb_typeof(f.value)<>'string'
        OR f.key !~ '^[a-z][a-z0-9-]*$'
        OR f.key IN ('from','chain-id','node','home','yes','generate-only','offline','output',
            'broadcast-mode','gas','gas-adjustment','fees','gas-prices','timeout-height',
            'account-number','sequence','sign-mode','fee-payer','fee-granter',
            'unordered','timeout-duration','aux','ledger','tip','dry-run')
        OR f.key LIKE 'keyring-%'
    ) THEN
        RAISE EXCEPTION 'invalid or worker-controlled transaction flags' USING ERRCODE='22023';
    END IF;
    IF _checks IS NULL OR jsonb_typeof(_checks)<>'array' THEN
        RAISE EXCEPTION 'transaction requires explicit authority checks' USING ERRCODE='22023';
    END IF;
    IF jsonb_array_length(_checks) NOT BETWEEN 1 AND 8 OR EXISTS (
        SELECT 1 FROM jsonb_array_elements(_checks) c WHERE jsonb_typeof(c)<>'object'
            OR NOT c ?& ARRAY['check_type','object_id','permission']
            OR CASE WHEN c->>'check_type' IN ('permission-address','permission-object') THEN
                NOT c ?& ARRAY['subject_id','operation']
                OR jsonb_typeof(c->'subject_id')<>'string' OR jsonb_typeof(c->'operation')<>'string'
                OR (c - ARRAY['check_type','object_id','permission','subject_id','operation']) <> '{}'::jsonb
            ELSE (c - ARRAY['check_type','object_id','permission']) <> '{}'::jsonb END
            OR jsonb_typeof(c->'check_type')<>'string' OR jsonb_typeof(c->'object_id')<>'string'
            OR jsonb_typeof(c->'permission')<>'number'
            OR (c->>'permission') !~ '^(0|[1-9][0-9]{0,7})$'
    ) THEN
        RAISE EXCEPTION 'invalid transaction authority checks' USING ERRCODE='22023';
    END IF;
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _context.transaction_ready IS DISTINCT FROM TRUE OR _context.protocol<>'v0.22.0' THEN
        RAISE EXCEPTION 'v0.22 indexed transaction context is not ready' USING ERRCODE='55000';
    END IF;
    INSERT INTO signer.tx(object_id,permission_requirement,module,command,args,flags,
        contract,requested_player_id,chain_id,prepared_height)
    VALUES(_object_id,0,_module,_command,_args,_flags,'v022-1',_player_id,_context.chain_id,_context.indexed_height::bigint)
    RETURNING * INTO _tx;
    INSERT INTO signer.tx_authority(tx_id,check_type,object_id,permission,subject_id,operation)
    SELECT _tx.id,c->>'check_type',c->>'object_id',(c->>'permission')::int,
        COALESCE(c->>'subject_id',''),COALESCE(c->>'operation','')
    FROM jsonb_array_elements(_checks) c;
    -- Kept for existing queue readers; selection uses each independent rule.
    UPDATE signer.tx SET permission_requirement=(SELECT bit_or(permission) FROM signer.tx_authority WHERE tx_id=_tx.id)
    WHERE id=_tx.id RETURNING * INTO _tx;
    RETURN to_jsonb(_tx);
END
$function$
;

CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite(_player_id character varying, _guild_id character varying, _target_player_id character varying, _substation_id character varying)
 RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_MEMBERSHIP_TRANSACTION_V022(_player_id,'guild-membership-invite',
        _guild_id,_target_player_id,_substation_id,NULL);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite_approve(_player_id character varying, _guild_id character varying, _target_player_id character varying, _substation_id character varying)
 RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_MEMBERSHIP_TRANSACTION_V022(_player_id,'guild-membership-invite-approve',
        _guild_id,_target_player_id,_substation_id,NULL);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite_deny(_player_id character varying, _guild_id character varying, _target_player_id character varying)
 RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_MEMBERSHIP_TRANSACTION_V022(_player_id,'guild-membership-invite-deny',
        _guild_id,_target_player_id,NULL,NULL);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite_revoke(_player_id character varying, _guild_id character varying, _target_player_id character varying)
 RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_MEMBERSHIP_TRANSACTION_V022(_player_id,'guild-membership-invite-revoke',
        _guild_id,_target_player_id,NULL,NULL);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_membership_join(_player_id character varying, _guild_id character varying, _substation_id character varying, _infusion_id character varying[])
 RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_MEMBERSHIP_TRANSACTION_V022(_player_id,'guild-membership-join',
        _guild_id,_player_id,_substation_id,_infusion_id);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_membership_kick(_player_id character varying, _guild_id character varying, _target_player_id character varying)
 RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_MEMBERSHIP_TRANSACTION_V022(_player_id,'guild-membership-kick',
        _guild_id,_target_player_id,NULL,NULL);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request(_player_id character varying, _guild_id character varying, _substation_id character varying)
 RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_MEMBERSHIP_TRANSACTION_V022(_player_id,'guild-membership-request',
        _guild_id,_player_id,_substation_id,NULL);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request_approve(_player_id character varying, _guild_id character varying, _target_player_id character varying, _substation_id character varying)
 RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_MEMBERSHIP_TRANSACTION_V022(_player_id,'guild-membership-request-approve',
        _guild_id,_target_player_id,_substation_id,NULL);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request_deny(_player_id character varying, _guild_id character varying, _target_player_id character varying)
 RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_MEMBERSHIP_TRANSACTION_V022(_player_id,'guild-membership-request-deny',
        _guild_id,_target_player_id,NULL,NULL);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request_revoke(_player_id character varying, _guild_id character varying, _target_player_id character varying)
 RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_MEMBERSHIP_TRANSACTION_V022(_player_id,'guild-membership-request-revoke',
        _guild_id,_target_player_id,NULL,NULL);
END
$BODY$;

COMMIT;
