-- Deploy structs-pg:function-signer-tx-20261030-gameplay to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'gameplay wrappers require the coordinated v022-1 signer contract';
    END IF;
END $$;

ALTER TABLE signer.tx_authority DROP CONSTRAINT tx_authority_check_type_check;
ALTER TABLE signer.tx_authority ADD CONSTRAINT tx_authority_check_type_check CHECK
    (check_type IN ('object','object-owner','address-owner','provider-open','permission-address','permission-object','energy','ugc','station-connection','registered'));
ALTER TABLE signer.tx_authority DROP CONSTRAINT tx_authority_subject_check;
ALTER TABLE signer.tx_authority ADD CONSTRAINT tx_authority_subject_check CHECK (
    (check_type IN ('object','object-owner','address-owner','provider-open') AND subject_id='' AND operation='' AND permission>0)
    OR (check_type IN ('permission-address','permission-object') AND operation IN ('grant','set','revoke')
        AND (operation='set' OR permission>0)
        AND ((check_type='permission-address' AND subject_id='') OR (check_type='permission-object' AND subject_id ~ '^1-[1-9][0-9]*$')))
    OR (check_type IN ('energy','ugc','registered') AND permission=0 AND subject_id='' AND operation='')
    OR (check_type='station-connection' AND permission=1024 AND operation='' AND subject_id='')
);

CREATE FUNCTION signer.GAMEPLAY_ID_ARGUMENT(_id VARCHAR,_prefix TEXT)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $BODY$
BEGIN
    IF _id IS NULL OR _prefix NOT IN ('1','2','5','9') OR _id !~ ('^'||_prefix||'-[1-9][0-9]{0,19}$') THEN
        RAISE EXCEPTION 'invalid gameplay object identity' USING ERRCODE='22023';
    END IF;
    PERFORM signer.UINT64_ARGUMENT(substring(_id from 3)::numeric,'gameplay object',FALSE);
    RETURN _id;
END
$BODY$;

CREATE FUNCTION signer.GAMEPLAY_AMBIT_ARGUMENT(_ambit VARCHAR)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $BODY$
BEGIN
    IF _ambit IS NULL OR _ambit NOT IN ('none','water','land','air','space','local') THEN
        RAISE EXCEPTION 'invalid gameplay ambit' USING ERRCODE='22023';
    END IF;
    RETURN _ambit;
END
$BODY$;

CREATE FUNCTION signer.GAMEPLAY_TARGETS_ARGUMENT(_targets VARCHAR)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $BODY$
DECLARE _id VARCHAR;
BEGIN
    IF _targets IS NULL OR _targets='' OR octet_length(_targets)>1048576 THEN
        RAISE EXCEPTION 'invalid or oversized attack target list' USING ERRCODE='22023';
    END IF;
    FOREACH _id IN ARRAY string_to_array(_targets,',') LOOP
        PERFORM signer.GAMEPLAY_ID_ARGUMENT(_id,'5');
    END LOOP;
    -- The protocol accepts repeated targets; preserve both their order and multiplicity.
    RETURN _targets;
END
$BODY$;

-- Keep reactor reads inside the command-specific helper. An inline subquery
-- in the shared SQL selector requires reactor SELECT even for unrelated callers.
CREATE FUNCTION signer.REGISTERED_REACTOR_CHECK(_tx_id INTEGER,_address VARCHAR)
RETURNS BOOLEAN LANGUAGE plpgsql STABLE AS $BODY$
DECLARE _tx signer.tx%ROWTYPE;
BEGIN
    SELECT * INTO _tx FROM signer.tx WHERE id=_tx_id;
    IF NOT FOUND OR _tx.contract IS DISTINCT FROM 'v022-1' OR _tx.module<>'structs'
        OR _tx.command<>'reactor-restart' OR _tx.object_id IS DISTINCT FROM _tx.requested_player_id
        OR jsonb_typeof(_tx.args) IS DISTINCT FROM 'array' THEN RETURN FALSE; END IF;
    RETURN jsonb_array_length(_tx.args)=1 AND jsonb_typeof(_tx.args->0)='string' AND _tx.flags='{}'::jsonb
        AND EXISTS (SELECT 1 FROM structs.player_address WHERE address=_address AND player_id=_tx.requested_player_id AND status='approved')
        AND NOT EXISTS (SELECT 1 FROM structs.vault WHERE address=_address)
        AND EXISTS (SELECT 1 FROM structs.reactor WHERE validator=_tx.args->>0);
END
$BODY$;

CREATE TEMP TABLE signer_gameplay_numeric_acl ON COMMIT DROP AS
    SELECT p.proowner,p.proacl,p.oid::regprocedure::text identity FROM pg_proc p WHERE p.oid IN
    ('signer.tx_struct_build_initiate(character varying,integer,character varying,integer)'::regprocedure,
     'signer.tx_struct_move(character varying,character varying,character varying,character varying,integer)'::regprocedure);
DROP FUNCTION signer.tx_struct_build_initiate(character varying,integer,character varying,integer);
DROP FUNCTION signer.tx_struct_move(character varying,character varying,character varying,character varying,integer);

CREATE OR REPLACE FUNCTION signer.tx_explore(_player_id character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','planet-explore',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_player_id,'1')),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_player_id,'permission',1)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_fleet_move(_player_id character varying, _fleet_id character varying, _destination_id character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_fleet_id,'structs','fleet-move',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_fleet_id,'9'),signer.GAMEPLAY_ID_ARGUMENT(_destination_id,'2')),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_fleet_id,'permission',1)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_planet_raid_complete(_player_id character varying, _fleet_id character varying, _proof character varying, _nonce character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_fleet_id,'structs','planet-raid-complete',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_fleet_id,'9'),_proof,_nonce),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_fleet_id,'permission',8388608)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_player_resume(_player_id character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    RAISE EXCEPTION 'player-resume has no RPC or CLI command in v0.22.0; refresh current player state instead' USING ERRCODE='0A000';
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_reactor_restart(_player_id character varying, _validator_address character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    IF _validator_address IS NULL OR _validator_address !~ '^structsvaloper1[ac-hj-np-z02-9]{1,100}$' THEN
        RAISE EXCEPTION 'invalid validator address' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','reactor-restart',jsonb_build_array(_validator_address),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','registered','object_id',_player_id,'permission',0)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_activate(_player_id character varying, _struct_id character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_struct_id,'structs','struct-activate',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_struct_id,'5')),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_struct_id,'permission',1)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_attack(_player_id character varying, _struct_id character varying, _target_struct_id character varying, _weapon_system character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    IF _weapon_system IS NULL OR _weapon_system NOT IN ('primaryWeapon','secondaryWeapon') THEN
        RAISE EXCEPTION 'invalid weapon system' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_struct_id,'structs','struct-attack',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_struct_id,'5'),signer.GAMEPLAY_TARGETS_ARGUMENT(_target_struct_id),_weapon_system),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_struct_id,'permission',1)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_build_cancel(_player_id character varying, _struct_id character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_struct_id,'structs','struct-build-cancel',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_struct_id,'5')),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_struct_id,'permission',1)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_build_complete(_player_id character varying, _struct_id character varying, _proof character varying, _nonce character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_struct_id,'structs','struct-build-complete',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_struct_id,'5'),_proof,_nonce),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_struct_id,'permission',1048576)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_build_initiate(_player_id character varying, _struct_type_id numeric, _operate_ambit character varying, _slot numeric)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','struct-build-initiate',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_player_id,'1'),signer.UINT64_ARGUMENT(_struct_type_id,'struct type',FALSE),signer.GAMEPLAY_AMBIT_ARGUMENT(_operate_ambit),signer.UINT64_ARGUMENT(_slot,'slot',TRUE)),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_player_id,'permission',1)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_deactivate(_player_id character varying, _struct_id character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_struct_id,'structs','struct-deactivate',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_struct_id,'5')),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_struct_id,'permission',1)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_defense_clear(_player_id character varying, _defender_struct_id character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_defender_struct_id,'structs','struct-defense-clear',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_defender_struct_id,'5')),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_defender_struct_id,'permission',1)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_defense_set(_player_id character varying, _defender_struct_id character varying, _protected_struct_id character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    IF _defender_struct_id=_protected_struct_id THEN
        RAISE EXCEPTION 'a struct cannot defend itself' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_defender_struct_id,'structs','struct-defense-set',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_defender_struct_id,'5'),signer.GAMEPLAY_ID_ARGUMENT(_protected_struct_id,'5')),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_defender_struct_id,'permission',1)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_move(_player_id character varying, _struct_id character varying, _location_type character varying, _ambit character varying, _slot numeric)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    IF _location_type IS NULL OR _location_type NOT IN ('planet','fleet') THEN
        RAISE EXCEPTION 'struct move destination must be planet or fleet' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_struct_id,'structs','struct-move',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_struct_id,'5'),_location_type,signer.GAMEPLAY_AMBIT_ARGUMENT(_ambit),signer.UINT64_ARGUMENT(_slot,'slot',TRUE)),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_struct_id,'permission',1)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_ore_mine_complete(_player_id character varying, _struct_id character varying, _proof character varying, _nonce character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_struct_id,'structs','struct-ore-mine-complete',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_struct_id,'5'),_proof,_nonce),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_struct_id,'permission',2097152)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_ore_refine_complete(_player_id character varying, _struct_id character varying, _proof character varying, _nonce character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_struct_id,'structs','struct-ore-refine-complete',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_struct_id,'5'),_proof,_nonce),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_struct_id,'permission',4194304)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_stealth_activate(_player_id character varying, _struct_id character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_struct_id,'structs','struct-stealth-activate',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_struct_id,'5')),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_struct_id,'permission',1)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_struct_stealth_deactivate(_player_id character varying, _struct_id character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_struct_id,'structs','struct-stealth-deactivate',jsonb_build_array(signer.GAMEPLAY_ID_ARGUMENT(_struct_id,'5')),'{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object-owner','object_id',_struct_id,'permission',1)));
END
$BODY$;

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
    WHERE t.id=_tx_id AND t.contract='v022-1' AND t.command<>'player-resume'
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
          AND (CASE WHEN rule.check_type='registered' THEN
              rule.object_id=t.requested_player_id AND signer.REGISTERED_REACTOR_CHECK(t.id,a.address)
          WHEN rule.check_type='ugc' THEN
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
        ('signer.tx_struct_build_initiate(character varying,integer,character varying,integer)','signer.tx_struct_build_initiate(character varying,numeric,character varying,numeric)'),
        ('signer.tx_struct_move(character varying,character varying,character varying,character varying,integer)','signer.tx_struct_move(character varying,character varying,character varying,character varying,numeric)')
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
COMMIT;
