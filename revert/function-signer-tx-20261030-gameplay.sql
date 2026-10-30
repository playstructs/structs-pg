-- Revert structs-pg:function-signer-tx-20261030-gameplay from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.tx IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract='v022-1' AND command IN ('planet-explore','fleet-move','planet-raid-complete','player-resume','reactor-restart','struct-activate','struct-attack','struct-build-cancel','struct-build-complete','struct-build-initiate','struct-deactivate','struct-defense-clear','struct-defense-set','struct-move','struct-ore-mine-complete','struct-ore-refine-complete','struct-stealth-activate','struct-stealth-deactivate'))
        OR EXISTS (SELECT 1 FROM signer.tx_authority WHERE check_type='registered') THEN
        RAISE EXCEPTION 'versioned gameplay requests exist; retain their contract or restore a verified checkpoint';
    END IF;
END $$;
CREATE TEMP TABLE signer_gameplay_numeric_acl ON COMMIT DROP AS
    SELECT p.proowner,p.proacl,p.oid::regprocedure::text identity FROM pg_proc p WHERE p.oid IN (
'signer.tx_struct_build_initiate(character varying,numeric,character varying,numeric)'::regprocedure,'signer.tx_struct_move(character varying,character varying,character varying,character varying,numeric)'::regprocedure);
CREATE OR REPLACE FUNCTION signer.tx_explore(_player_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','planet-explore',jsonb_build_array(_player_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_fleet_move(_player_id character varying, _fleet_id character varying, _destination_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','fleet-move',jsonb_build_array(_fleet_id, _destination_id ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_planet_raid_complete(_player_id character varying, _fleet_id character varying, _proof character varying, _nonce character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,8388608,'structs','planet-raid-complete',jsonb_build_array(_fleet_id, _proof, _nonce ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_player_resume(_player_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','player-resume',jsonb_build_array(_player_id ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_reactor_restart(_player_id character varying, _validator_address character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _player_id,
            1,
            'structs',
            'reactor-restart',
            jsonb_build_array(_validator_address),
            '{}'
        );
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_activate(_player_id character varying, _struct_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-activate',jsonb_build_array(_struct_id ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_attack(_player_id character varying, _struct_id character varying, _target_struct_id character varying, _weapon_system character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-attack',jsonb_build_array(_struct_id, _target_struct_id, _weapon_system ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_build_cancel(_player_id character varying, _struct_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-build-cancel',jsonb_build_array(_struct_id),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_build_complete(_player_id character varying, _struct_id character varying, _proof character varying, _nonce character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1048576,'structs','struct-build-complete',jsonb_build_array(_struct_id, _proof, _nonce ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_build_initiate(_player_id character varying, _struct_type_id integer, _operate_ambit character varying, _slot integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-build-initiate',jsonb_build_array(_player_id, _struct_type_id, _operate_ambit,_slot ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_deactivate(_player_id character varying, _struct_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-deactivate',jsonb_build_array(_struct_id ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_defense_clear(_player_id character varying, _defender_struct_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-defense-clear',jsonb_build_array(_defender_struct_id ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_defense_set(_player_id character varying, _defender_struct_id character varying, _protected_struct_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-defense-set',jsonb_build_array(_defender_struct_id, _protected_struct_id ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_move(_player_id character varying, _struct_id character varying, _location_type character varying, _ambit character varying, _slot integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-move',jsonb_build_array(_struct_id, _location_type, _ambit, _slot),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_ore_mine_complete(_player_id character varying, _struct_id character varying, _proof character varying, _nonce character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,2097152,'structs','struct-ore-mine-complete',jsonb_build_array(_struct_id, _proof, _nonce ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_ore_refine_complete(_player_id character varying, _struct_id character varying, _proof character varying, _nonce character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,4194304,'structs','struct-ore-refine-complete',jsonb_build_array(_struct_id, _proof, _nonce ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_stealth_activate(_player_id character varying, _struct_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-stealth-activate',jsonb_build_array(_struct_id ),'{}');
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.tx_struct_stealth_deactivate(_player_id character varying, _struct_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,1,'structs','struct-stealth-deactivate',jsonb_build_array(_struct_id ),'{}');
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
      AND CASE WHEN t.command::text LIKE 'allocation-%' OR (t.command::text LIKE 'substation-%'
          AND t.command NOT IN ('substation-update-name','substation-update-pfp'))
          THEN EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id
              AND rule.check_type='energy' AND rule.object_id=t.object_id) ELSE TRUE END
      AND CASE WHEN t.command IN ('player-update-name','player-update-pfp','player-update-pfp-cr-attributes',
          'planet-update-name','substation-update-name','substation-update-pfp')
          THEN signer.COSMETIC_CONTEXT_CHECK(t.id) AND EXISTS (SELECT 1 FROM signer.tx_authority rule
              WHERE rule.tx_id=t.id AND rule.object_id=t.args->>0 AND rule.check_type IN ('ugc','energy')) ELSE TRUE END
      AND (t.command<>'address-register' OR signer.REGISTRATION_CONTEXT_CHECK(t.id))
      AND (t.command NOT IN ('address-revoke','player-update-primary-address') OR signer.ADDRESS_MANAGEMENT_CHECK(t.id))
      AND EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id)
      AND NOT EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id
          AND (CASE WHEN rule.check_type='ugc' THEN
              rule.object_id=t.args->>0 AND signer.UGC_PERMISSION_CHECK(a.address,rule.object_id)
          WHEN rule.check_type='station-connection' THEN signer.STATION_CONNECTION_CHECK(a.address,rule.object_id)
          WHEN rule.check_type='energy' THEN
              rule.object_id=t.object_id AND signer.ENERGY_CONTEXT_CHECK(t.id,a.address)
          WHEN rule.check_type IN ('permission-address','permission-object') THEN
              signer.PERMISSION_MUTATION_CHECK(a.address,rule.check_type,rule.object_id,
                  rule.subject_id,rule.operation,rule.permission)
          ELSE signer.TRANSACTION_AUTHORITY_CHECK(a.address,t.requested_player_id,
              rule.check_type,rule.object_id,rule.permission) END) IS DISTINCT FROM TRUE);
$function$
;
DO $$
DECLARE f RECORD; a RECORD; target REGPROCEDURE; grantee_name TEXT;
BEGIN
    FOR f IN SELECT p.proowner,p.proacl,v.target FROM (VALUES
        ('signer.tx_struct_build_initiate(character varying,numeric,character varying,numeric)','signer.tx_struct_build_initiate(character varying,integer,character varying,integer)'),
        ('signer.tx_struct_move(character varying,character varying,character varying,character varying,numeric)','signer.tx_struct_move(character varying,character varying,character varying,character varying,integer)')
    ) v(source,target) JOIN pg_temp.signer_gameplay_numeric_acl p ON p.identity=v.source
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
DROP FUNCTION signer.tx_struct_build_initiate(character varying,numeric,character varying,numeric);
DROP FUNCTION signer.tx_struct_move(character varying,character varying,character varying,character varying,numeric);
ALTER TABLE signer.tx_authority DROP CONSTRAINT tx_authority_check_type_check;
ALTER TABLE signer.tx_authority ADD CONSTRAINT tx_authority_check_type_check CHECK ((check_type = ANY (ARRAY['object'::text, 'object-owner'::text, 'address-owner'::text, 'provider-open'::text, 'permission-address'::text, 'permission-object'::text, 'energy'::text, 'ugc'::text, 'station-connection'::text])));
ALTER TABLE signer.tx_authority DROP CONSTRAINT tx_authority_subject_check;
ALTER TABLE signer.tx_authority ADD CONSTRAINT tx_authority_subject_check CHECK ((((check_type = ANY (ARRAY['object'::text, 'object-owner'::text, 'address-owner'::text, 'provider-open'::text])) AND ((subject_id)::text = ''::text) AND (operation = ''::text) AND (permission > 0)) OR ((check_type = ANY (ARRAY['permission-address'::text, 'permission-object'::text])) AND (operation = ANY (ARRAY['grant'::text, 'set'::text, 'revoke'::text])) AND ((operation = 'set'::text) OR (permission > 0)) AND (((check_type = 'permission-address'::text) AND ((subject_id)::text = ''::text)) OR ((check_type = 'permission-object'::text) AND ((subject_id)::text ~ '^1-[1-9][0-9]*$'::text)))) OR ((check_type = 'energy'::text) AND (permission = 0) AND ((subject_id)::text = ''::text) AND (operation = ''::text)) OR ((check_type = 'ugc'::text) AND (permission = 0) AND (operation = ''::text) AND ((subject_id)::text = ''::text)) OR ((check_type = 'station-connection'::text) AND (permission = 1024) AND (operation = ''::text) AND ((subject_id)::text = ''::text))));
DROP FUNCTION signer.REGISTERED_REACTOR_CHECK(INTEGER,VARCHAR);
DROP FUNCTION signer.GAMEPLAY_TARGETS_ARGUMENT(VARCHAR);
DROP FUNCTION signer.GAMEPLAY_AMBIT_ARGUMENT(VARCHAR);
DROP FUNCTION signer.GAMEPLAY_ID_ARGUMENT(VARCHAR,TEXT);
COMMIT;
