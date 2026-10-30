-- Deploy structs-pg:function-signer-tx-20261030-cosmetic to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'cosmetic wrappers require the coordinated v022-1 signer contract';
    END IF;
END $$;

ALTER TABLE signer.tx_authority DROP CONSTRAINT tx_authority_check_type_check;
ALTER TABLE signer.tx_authority ADD CONSTRAINT tx_authority_check_type_check CHECK
    (check_type IN ('object','object-owner','address-owner','provider-open','permission-address','permission-object','energy','ugc','station-connection'));
ALTER TABLE signer.tx_authority DROP CONSTRAINT tx_authority_subject_check;
ALTER TABLE signer.tx_authority ADD CONSTRAINT tx_authority_subject_check CHECK (
    (check_type IN ('object','object-owner','address-owner','provider-open') AND subject_id='' AND operation='' AND permission>0)
    OR (check_type IN ('permission-address','permission-object') AND operation IN ('grant','set','revoke')
        AND (operation='set' OR permission>0)
        AND ((check_type='permission-address' AND subject_id='') OR (check_type='permission-object' AND subject_id ~ '^1-[1-9][0-9]*$')))
    OR (check_type='energy' AND permission=0 AND subject_id='' AND operation='')
    OR (check_type='ugc' AND permission=0 AND operation='' AND subject_id='')
    OR (check_type='station-connection' AND permission=1024 AND operation='' AND subject_id='')
);

-- The selected moderation guild is retained in a separate object rule; this
-- guard binds that guild to the target's live ownership/membership at claim.
CREATE FUNCTION signer.COSMETIC_CONTEXT_CHECK(_tx_id INTEGER)
RETURNS BOOLEAN LANGUAGE plpgsql STABLE AS $BODY$
DECLARE _tx signer.tx%ROWTYPE; _owner VARCHAR; _guild VARCHAR; _target VARCHAR;
BEGIN
    SELECT * INTO _tx FROM signer.tx WHERE id=_tx_id;
    IF NOT FOUND THEN RETURN FALSE; END IF;
    IF _tx.command NOT IN ('player-update-name','player-update-pfp','player-update-pfp-cr-attributes',
        'planet-update-name','substation-update-name','substation-update-pfp') THEN RETURN FALSE; END IF;
    IF jsonb_typeof(_tx.args) IS DISTINCT FROM 'array' THEN RETURN FALSE; END IF;
    IF jsonb_array_length(_tx.args)<>2 OR _tx.flags<>'{}'::jsonb THEN RETURN FALSE; END IF;
    _target:=_tx.args->>0;
    _owner:=signer.PERMISSION_OBJECT_OWNER(_target);
    IF _owner IS NULL THEN RETURN FALSE; END IF;
    IF split_part(_owner,'-',1)='0' THEN _guild:=_owner;
    ELSE SELECT guild_id INTO _guild FROM structs.player WHERE id=_owner; END IF;
    -- A target object id identifies a normal edit. A guild object id identifies
    -- the existing guild-moderation wrappers and fixes the intended boundary.
    RETURN _tx.object_id=_target OR (_tx.object_id=_guild AND EXISTS (SELECT 1 FROM signer.tx_authority
        WHERE tx_id=_tx.id AND check_type='object' AND object_id=_guild AND permission=16777216));
END
$BODY$;

CREATE FUNCTION signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id VARCHAR,_command structs.signer_tx_type,
    _target_id VARCHAR,_value VARCHAR,_guild_id VARCHAR DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _prefix TEXT; _checks JSONB; _object VARCHAR:=_target_id; _selected VARCHAR;
BEGIN
    _prefix:=CASE WHEN _command IN ('guild-update-name','guild-update-pfp') THEN '0'
        WHEN _command IN ('player-update-name','player-update-pfp','player-update-pfp-cr-attributes') THEN '1'
        WHEN _command='planet-update-name' THEN '2'
        WHEN _command IN ('substation-update-name','substation-update-pfp') THEN '4' END;
    IF _prefix IS NULL OR _target_id IS NULL OR _target_id !~ ('^'||_prefix||'-[1-9][0-9]{0,19}$') OR _value IS NULL THEN
        RAISE EXCEPTION 'invalid cosmetic target or value' USING ERRCODE='22023';
    END IF;
    PERFORM signer.UINT64_ARGUMENT(substring(_target_id from 3)::numeric,'cosmetic target',FALSE);
    IF signer.PERMISSION_OBJECT_OWNER(_target_id) IS NULL THEN
        RAISE EXCEPTION 'cosmetic target does not exist' USING ERRCODE='22023';
    END IF;
    IF _prefix='0' THEN
        _checks:=jsonb_build_array(jsonb_build_object('check_type','object','object_id',_target_id,'permission',4));
    ELSE
        _checks:=jsonb_build_array(jsonb_build_object('check_type','ugc','object_id',_target_id,'permission',0));
    END IF;
    IF _guild_id IS NOT NULL THEN
        _selected:=signer.SELECT_SIGNING_GUILD(_player_id,_guild_id);
        _object:=_selected;
        _checks:=_checks||jsonb_build_array(jsonb_build_object('check_type','object','object_id',_selected,'permission',16777216));
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_object,'structs',_command,jsonb_build_array(_target_id,_value),'{}'::jsonb,_checks);
END
$BODY$;
REVOKE ALL ON FUNCTION signer.CREATE_COSMETIC_TRANSACTION_V022(VARCHAR,structs.signer_tx_type,VARCHAR,VARCHAR,VARCHAR) FROM PUBLIC;

CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_planet_name(_player_id character varying, _guild_id character varying, _planet_id character varying, _name character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id,'planet-update-name',_planet_id,_name,COALESCE(_guild_id,''));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_player_name(_player_id character varying, _guild_id character varying, _target_player_id character varying, _name character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id,'player-update-name',_target_player_id,_name,COALESCE(_guild_id,''));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_player_pfp(_player_id character varying, _guild_id character varying, _target_player_id character varying, _pfp character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id,'player-update-pfp',_target_player_id,_pfp,COALESCE(_guild_id,''));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_player_pfp_cr_attributes(_player_id character varying, _guild_id character varying, _target_player_id character varying, _pfp_cr_attributes character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id,'player-update-pfp-cr-attributes',_target_player_id,_pfp_cr_attributes,COALESCE(_guild_id,''));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_substation_name(_player_id character varying, _guild_id character varying, _substation_id character varying, _name character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id,'substation-update-name',_substation_id,_name,COALESCE(_guild_id,''));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_substation_pfp(_player_id character varying, _guild_id character varying, _substation_id character varying, _pfp character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id,'substation-update-pfp',_substation_id,_pfp,COALESCE(_guild_id,''));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_update_name(_player_id character varying, _guild_id character varying, _name character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id,'guild-update-name',signer.SELECT_SIGNING_GUILD(_player_id,_guild_id),_name);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_update_pfp(_player_id character varying, _guild_id character varying, _pfp character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id,'guild-update-pfp',signer.SELECT_SIGNING_GUILD(_player_id,_guild_id),_pfp);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_planet_update_name(_player_id character varying, _planet_id character varying, _name character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id,'planet-update-name',_planet_id,_name);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_player_update_name(_player_id character varying, _name character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id,'player-update-name',_player_id,_name);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_player_update_pfp(_player_id character varying, _pfp character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id,'player-update-pfp',_player_id,_pfp);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_player_update_pfp_cr_attributes(_player_id character varying, _pfp_cr_attributes character varying)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_COSMETIC_TRANSACTION_V022(_player_id,'player-update-pfp-cr-attributes',_player_id,_pfp_cr_attributes);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_guild_update_entry_substation_id(_player_id VARCHAR,_guild_id VARCHAR,_entry_substation_id VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
DECLARE _selected VARCHAR; _station VARCHAR:=COALESCE(_entry_substation_id,''); _checks JSONB;
BEGIN
    _selected:=signer.SELECT_SIGNING_GUILD(_player_id,_guild_id);
    _checks:=jsonb_build_array(jsonb_build_object('check_type','object','object_id',_selected,'permission',65536));
    IF _station<>'' THEN
        IF NOT signer.ENERGY_ID_VALID(_station,ARRAY['4']) THEN
            RAISE EXCEPTION 'invalid entry substation' USING ERRCODE='22023';
        END IF;
        _checks:=_checks||jsonb_build_array(jsonb_build_object('check_type','station-connection','object_id',_station,'permission',1024));
    END IF;
    -- Empty is the chain's existing no-op, not a request to clear the setting.
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_selected,'structs','guild-update-entry-substation-id',
        jsonb_build_array(_selected,_station),'{}'::jsonb,_checks);
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
COMMIT;
