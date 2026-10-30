-- Revert structs-pg:function-signer-tx-20261030-registration from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.tx,signer.tx_registration_proof,signer.account IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx_registration_proof)
        OR EXISTS (SELECT 1 FROM signer.account WHERE registration_tx_id IS NOT NULL)
        OR EXISTS (SELECT 1 FROM signer.tx WHERE contract='v022-1'
            AND command IN ('address-register','address-revoke','player-update-primary-address')) THEN
        RAISE EXCEPTION 'versioned address requests exist; retain their proof and contract or restore a verified checkpoint';
    END IF;
END $$;
CREATE OR REPLACE FUNCTION signer.tx_address_register(_player_id character varying, _address_to_register character varying, _proof_pub_key character varying, _proof_signature character varying, _permissions integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,2,'structs','address-register',jsonb_build_array(_address_to_register, _proof_pub_key, _proof_signature, _permissions),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.update_pending_account(_account_id integer, _player_id character varying, _address character varying, _pubkey character varying, _signature character varying, _permission integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
    BEGIN
        UPDATE signer.account SET address=_address, status='pending' WHERE id=_account_id;

        INSERT INTO signer.tx (object_id, module, command, args, permission_requirement )
            VALUES (_player_id, 'structs', 'address-register', jsonb_build_array(_address , _pubkey ,_signature , _permission), 33554431);
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_address_revoke(_player_id character varying, _address_to_revoke character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,2,'structs','address-revoke',jsonb_build_array(_address_to_revoke),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_player_update_primary_address(_player_id character varying, _primary_address character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,4,'structs','player-update-primary-address',jsonb_build_array(_primary_address),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.authorized_accounts_v022(_tx_id integer)
 RETURNS TABLE(account_id integer, address character varying, status structs.signer_account_status)
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
      AND EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id)
      AND NOT EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id
          AND (CASE WHEN rule.check_type IN ('permission-address','permission-object') THEN
              signer.PERMISSION_MUTATION_CHECK(a.address,rule.check_type,rule.object_id,
                  rule.subject_id,rule.operation,rule.permission)
          ELSE signer.TRANSACTION_AUTHORITY_CHECK(a.address,t.requested_player_id,
              rule.check_type,rule.object_id,rule.permission) END) IS DISTINCT FROM TRUE);
$function$
;
DROP FUNCTION signer.tx_address_register(character varying,character varying,character varying,character varying,numeric,jsonb,character varying);
DROP FUNCTION signer.update_pending_account(integer,character varying,character varying,character varying,character varying,numeric,jsonb,character varying);
DROP FUNCTION signer.CREATE_ADDRESS_REGISTRATION_V022(character varying,character varying,character varying,character varying,character varying,numeric,jsonb);
DROP FUNCTION signer.REGISTRATION_CONTEXT(character varying,character varying,character varying,character varying,numeric,jsonb);
DROP FUNCTION signer.REGISTRATION_PROOF_V022(integer);
DROP FUNCTION signer.REGISTRATION_CONTEXT_CHECK(integer);
DROP FUNCTION signer.ADDRESS_MANAGEMENT_CHECK(integer);
ALTER TABLE signer.account DROP COLUMN registration_tx_id;
DROP TABLE signer.tx_registration_proof;
DROP FUNCTION signer.REGISTRATION_PROOF_IMMUTABLE();
COMMIT;
