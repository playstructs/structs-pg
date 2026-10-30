-- Revert structs-pg:function-signer-tx-20261030-energy from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.tx IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract='v022-1' AND command IN ('allocation-create','allocation-delete','allocation-transfer','allocation-update','substation-allocation-connect','substation-allocation-disconnect','substation-create','substation-delete','substation-player-connect','substation-player-disconnect','substation-player-migrate','substation-update-name','substation-update-pfp'))
        OR EXISTS (SELECT 1 FROM signer.tx_authority WHERE check_type='energy') THEN
        RAISE EXCEPTION 'versioned energy requests exist; retain their contract or restore a verified checkpoint';
    END IF;
END $$;
CREATE OR REPLACE FUNCTION signer.tx_allocation_connect(_player_id character varying, _allocation_id character varying, _substation_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,2048,'structs','substation-allocation-connect',jsonb_build_array(_allocation_id, _substation_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_allocation_create(_allocation_type character varying, _source_id character varying, _amount numeric, _controller character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    DECLARE
            _flags JSONB;
    BEGIN

        IF _controller IS NOT NULL AND _controller <> '' THEN
            _flags := json_build_object('controller', _controller, 'type', _allocation_type);
        ELSE
            _flags := json_build_object('type', _allocation_type);
        END IF;

        PERFORM signer.CREATE_TRANSACTION(_source_id,256,'structs','allocation-create',jsonb_build_array(_source_id, _amount),_flags);
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_allocation_delete(_player_id character varying, _allocation_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8,'structs','allocation-delete',jsonb_build_array(_allocation_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_allocation_disconnect(_player_id character varying, _allocation_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,2048,'structs','substation-allocation-disconnect',jsonb_build_array(_allocation_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_allocation_transfer(_player_id character varying, _allocation_id character varying, _controller character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,4,'structs','allocation-transfer',jsonb_build_array(_allocation_id, _controller),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_allocation_update(_player_id character varying, _allocation_id character varying, _power numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,4,'structs','allocation-update',jsonb_build_array(_allocation_id, _power),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_substation_create(_player_id character varying, _allocation_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,256,'structs','substation-create',jsonb_build_array(_allocation_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_substation_delete(_player_id character varying, _substation_id character varying, _migration_substation_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,8,'structs','substation-delete',jsonb_build_array( _substation_id, _migration_substation_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_substation_player_connect(_player_id character varying, _substation_id character varying, _target_player_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,1024,'structs','substation-player-connect',jsonb_build_array(_substation_id, _target_player_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_substation_player_disconnect(_substation_id character varying, _target_player_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,1024,'structs','substation-player-disconnect',jsonb_build_array(_target_player_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_substation_player_migrate(_player_id character varying, _substation_id character varying, _target_player_ids character varying[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,1024,'structs','substation-player-migrate',jsonb_build_array( _substation_id, _target_player_ids),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_substation_update_name(_player_id character varying, _substation_id character varying, _name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,4,'structs','substation-update-name',jsonb_build_array(_substation_id, _name),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_substation_update_pfp(_player_id character varying, _substation_id character varying, _pfp character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_substation_id,4,'structs','substation-update-pfp',jsonb_build_array(_substation_id, _pfp),'{}');
    END
    $function$
;
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
ALTER TABLE signer.tx_authority DROP CONSTRAINT tx_authority_check_type_check;
ALTER TABLE signer.tx_authority ADD CONSTRAINT tx_authority_check_type_check CHECK ((check_type = ANY (ARRAY['object'::text, 'object-owner'::text, 'address-owner'::text, 'provider-open'::text, 'permission-address'::text, 'permission-object'::text])));
ALTER TABLE signer.tx_authority DROP CONSTRAINT tx_authority_subject_check;
ALTER TABLE signer.tx_authority ADD CONSTRAINT tx_authority_subject_check CHECK ((((check_type = ANY (ARRAY['object'::text, 'object-owner'::text, 'address-owner'::text, 'provider-open'::text])) AND ((subject_id)::text = ''::text) AND (operation = ''::text) AND (permission > 0)) OR ((check_type = ANY (ARRAY['permission-address'::text, 'permission-object'::text])) AND (operation = ANY (ARRAY['grant'::text, 'set'::text, 'revoke'::text])) AND ((operation = 'set'::text) OR (permission > 0)) AND (((check_type = 'permission-address'::text) AND ((subject_id)::text = ''::text)) OR ((check_type = 'permission-object'::text) AND ((subject_id)::text ~ '^1-[1-9][0-9]*$'::text))))));
DROP FUNCTION signer.tx_allocation_create(character varying,character varying,character varying,numeric,character varying);
DROP FUNCTION signer.tx_substation_create(character varying,character varying,character varying);
DROP FUNCTION signer.tx_substation_player_disconnect(character varying,character varying,character varying);
DROP FUNCTION signer.CREATE_ENERGY_TRANSACTION_V022(VARCHAR,VARCHAR,structs.signer_tx_type,JSONB,JSONB);
DROP FUNCTION signer.ENERGY_CONTEXT_CHECK(INTEGER,VARCHAR);
DROP FUNCTION signer.UGC_PERMISSION_CHECK(VARCHAR,VARCHAR);
DROP FUNCTION signer.STATION_CONNECTION_CHECK(VARCHAR,VARCHAR);
DROP FUNCTION signer.ALLOCATION_SOURCE_GUILD(VARCHAR);
DROP FUNCTION signer.ENERGY_REQUEST_VALID(TEXT,JSONB,JSONB);
DROP FUNCTION signer.ENERGY_ID_VALID(TEXT,TEXT[]);
COMMIT;
