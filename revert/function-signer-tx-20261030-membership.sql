-- Revert structs-pg:function-signer-tx-20261030-membership from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.tx IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract='v022-1' AND command::text LIKE 'guild-membership-%') THEN
        RAISE EXCEPTION 'versioned membership requests exist; retain their consent and authority contract or restore a verified checkpoint';
    END IF;
END $$;
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
            'account-number','sequence','sign-mode','fee-payer','fee-granter')
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
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,512,'structs','guild-membership-invite',jsonb_build_array( _guild_id, _target_player_id, _substation_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite_approve(_player_id character varying, _guild_id character varying, _target_player_id character varying, _substation_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,512,'structs','guild-membership-invite-approve',jsonb_build_array( _guild_id, _target_player_id, _substation_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite_deny(_player_id character varying, _guild_id character varying, _target_player_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,512,'structs','guild-membership-invite-deny',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_membership_invite_revoke(_player_id character varying, _guild_id character varying, _target_player_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,512,'structs','guild-membership-invite-revoke',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_membership_join(_player_id character varying, _guild_id character varying, _substation_id character varying, _infusion_id character varying[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,512,'structs','guild-membership-join',jsonb_build_array(_guild_id, _player_id, _substation_id, _infusion_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_membership_kick(_player_id character varying, _guild_id character varying, _target_player_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,512,'structs','guild-membership-kick',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request(_player_id character varying, _guild_id character varying, _substation_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,512,'structs','guild-membership-request',jsonb_build_array( _guild_id, _player_id, _substation_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request_approve(_player_id character varying, _guild_id character varying, _target_player_id character varying, _substation_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,512,'structs','guild-membership-request-approve',jsonb_build_array( _guild_id, _target_player_id, _substation_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request_deny(_player_id character varying, _guild_id character varying, _target_player_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,512,'structs','guild-membership-request-deny',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_guild_membership_request_revoke(_player_id character varying, _guild_id character varying, _target_player_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,512,'structs','guild-membership-request-revoke',jsonb_build_array( _guild_id, _target_player_id),'{}');
    END
    $function$
;
DROP FUNCTION signer.CREATE_MEMBERSHIP_TRANSACTION_V022(CHARACTER VARYING,structs.signer_tx_type,CHARACTER VARYING,CHARACTER VARYING,CHARACTER VARYING,CHARACTER VARYING[]);
DROP FUNCTION signer.MEMBERSHIP_CONTEXT_CHECK(INTEGER,CHARACTER VARYING);
DROP FUNCTION signer.MEMBERSHIP_ARGUMENTS(TEXT,CHARACTER VARYING,CHARACTER VARYING,CHARACTER VARYING,CHARACTER VARYING[]);
DROP FUNCTION signer.MEMBERSHIP_STATION_ACCEPTING(CHARACTER VARYING);
COMMIT;
