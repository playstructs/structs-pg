-- Deploy structs-pg:function-signer-tx-20261030-energy to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'energy wrappers require the coordinated v022-1 signer contract';
    END IF;
END $$;

-- A command rule represents runtime alternatives (source OR allocation,
-- target player OR current substation). A zero mask is not permissionless:
-- ENERGY_CONTEXT_CHECK resolves and checks each permitted path's own key bit.
ALTER TABLE signer.tx_authority DROP CONSTRAINT tx_authority_check_type_check;
ALTER TABLE signer.tx_authority ADD CONSTRAINT tx_authority_check_type_check CHECK
    (check_type IN ('object','object-owner','address-owner','provider-open','permission-address','permission-object','energy'));
ALTER TABLE signer.tx_authority DROP CONSTRAINT tx_authority_subject_check;
ALTER TABLE signer.tx_authority ADD CONSTRAINT tx_authority_subject_check CHECK (
    (check_type IN ('object','object-owner','address-owner','provider-open') AND subject_id='' AND operation='' AND permission>0)
    OR (check_type IN ('permission-address','permission-object') AND operation IN ('grant','set','revoke')
        AND (operation='set' OR permission>0)
        AND ((check_type='permission-address' AND subject_id='') OR (check_type='permission-object' AND subject_id ~ '^1-[1-9][0-9]*$')))
    OR (check_type='energy' AND permission=0 AND subject_id='' AND operation='')
);

CREATE FUNCTION signer.ENERGY_ID_VALID(_id TEXT,_prefixes TEXT[])
RETURNS BOOLEAN LANGUAGE sql IMMUTABLE AS $BODY$
    SELECT CASE WHEN _id ~ '^(0|1|3|4|6)-[1-9][0-9]{0,19}$'
        AND split_part(_id,'-',1)=ANY(_prefixes)
        THEN split_part(_id,'-',2)::numeric<=18446744073709551615 ELSE FALSE END;
$BODY$;

CREATE FUNCTION signer.ENERGY_REQUEST_VALID(_command TEXT,_args JSONB,_flags JSONB)
RETURNS BOOLEAN LANGUAGE plpgsql IMMUTABLE AS $BODY$
DECLARE _n INTEGER; _first TEXT; _second TEXT; _ids TEXT[];
BEGIN
    IF jsonb_typeof(_args) IS DISTINCT FROM 'array' OR jsonb_typeof(_flags) IS DISTINCT FROM 'object' THEN RETURN FALSE; END IF;
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(_args) x WHERE jsonb_typeof(x)<>'string') THEN RETURN FALSE; END IF;
    _n := jsonb_array_length(_args); _first := _args->>0; _second := _args->>1;
    IF _command='allocation-create' THEN
        RETURN _n=2 AND signer.ENERGY_ID_VALID(_first,ARRAY['0','1','3','4'])
            AND _flags ?& ARRAY['allocation-type','controller'] AND (_flags-ARRAY['allocation-type','controller'])='{}'::jsonb
            AND _flags->>'allocation-type' IN ('static','dynamic','automated','provider-agreement')
            AND signer.ENERGY_ID_VALID(_flags->>'controller',ARRAY['0','1'])
            AND CASE WHEN _second ~ '^(0|[1-9][0-9]{0,19})$' THEN _second::numeric<=18446744073709551615
                AND (_second<>'0' OR _flags->>'allocation-type'='automated') ELSE FALSE END;
    END IF;
    IF _flags<>'{}'::jsonb THEN RETURN FALSE; END IF;
    CASE _command
        WHEN 'allocation-delete','substation-allocation-disconnect' THEN RETURN _n=1 AND signer.ENERGY_ID_VALID(_first,ARRAY['6']);
        WHEN 'allocation-transfer' THEN RETURN _n=2 AND signer.ENERGY_ID_VALID(_first,ARRAY['6']) AND signer.ENERGY_ID_VALID(_second,ARRAY['0','1']);
        WHEN 'allocation-update' THEN RETURN _n=2 AND signer.ENERGY_ID_VALID(_first,ARRAY['6'])
            AND CASE WHEN _second ~ '^[1-9][0-9]{0,19}$' THEN _second::numeric<=18446744073709551615 ELSE FALSE END;
        WHEN 'substation-allocation-connect' THEN RETURN _n=2 AND signer.ENERGY_ID_VALID(_first,ARRAY['6']) AND signer.ENERGY_ID_VALID(_second,ARRAY['4']);
        WHEN 'substation-create' THEN RETURN _n=2 AND signer.ENERGY_ID_VALID(_first,ARRAY['0','1']) AND signer.ENERGY_ID_VALID(_second,ARRAY['6']);
        WHEN 'substation-delete' THEN RETURN _n=2 AND signer.ENERGY_ID_VALID(_first,ARRAY['4'])
            AND (_second='' OR signer.ENERGY_ID_VALID(_second,ARRAY['4']));
        WHEN 'substation-player-connect' THEN RETURN _n=2 AND signer.ENERGY_ID_VALID(_first,ARRAY['4']) AND signer.ENERGY_ID_VALID(_second,ARRAY['1']);
        WHEN 'substation-player-disconnect' THEN RETURN _n=1 AND signer.ENERGY_ID_VALID(_first,ARRAY['1']);
        WHEN 'substation-player-migrate' THEN
            _ids := string_to_array(_second,',');
            RETURN _n=2 AND signer.ENERGY_ID_VALID(_first,ARRAY['4']) AND cardinality(_ids)>0 AND octet_length(_second)<=1048576
                AND NOT EXISTS (SELECT 1 FROM unnest(_ids) id WHERE NOT signer.ENERGY_ID_VALID(id,ARRAY['1']))
                AND (SELECT count(DISTINCT id) FROM unnest(_ids) id)=cardinality(_ids);
        WHEN 'substation-update-name','substation-update-pfp' THEN RETURN _n=2 AND signer.ENERGY_ID_VALID(_first,ARRAY['4']);
        ELSE RETURN FALSE;
    END CASE;
END
$BODY$;

CREATE FUNCTION signer.ALLOCATION_SOURCE_GUILD(_source CHARACTER VARYING)
RETURNS CHARACTER VARYING LANGUAGE plpgsql STABLE AS $BODY$
DECLARE _owner CHARACTER VARYING;
BEGIN
    IF split_part(_source,'-',1)='0' THEN _owner:=_source;
    ELSE _owner:=signer.PERMISSION_OBJECT_OWNER(_source); END IF;
    RETURN (SELECT id FROM structs.guild WHERE id=_owner);
END
$BODY$;

CREATE FUNCTION signer.STATION_CONNECTION_CHECK(_address CHARACTER VARYING,_id CHARACTER VARYING)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $BODY$
    SELECT EXISTS (SELECT 1 FROM structs.substation WHERE id=_id AND deletion_pending IS FALSE)
        AND signer.PERMISSION_CHECK(_address,_id,1024) IS TRUE;
$BODY$;

CREATE FUNCTION signer.UGC_PERMISSION_CHECK(_address CHARACTER VARYING,_id CHARACTER VARYING)
RETURNS BOOLEAN LANGUAGE plpgsql STABLE AS $BODY$
DECLARE _owner CHARACTER VARYING; _guild CHARACTER VARYING;
BEGIN
    IF signer.PERMISSION_CHECK(_address,_id,4) THEN RETURN TRUE; END IF;
    _owner:=signer.PERMISSION_OBJECT_OWNER(_id);
    IF split_part(_owner,'-',1)='0' THEN _guild:=_owner;
    ELSE SELECT guild_id INTO _guild FROM structs.player WHERE id=_owner; END IF;
    RETURN signer.PERMISSION_CHECK(_address,_guild,16777216) IS TRUE;
END
$BODY$;

CREATE FUNCTION signer.ENERGY_CONTEXT_CHECK(_tx_id INTEGER,_address CHARACTER VARYING)
RETURNS BOOLEAN LANGUAGE plpgsql STABLE AS $BODY$
DECLARE
    _tx signer.tx%ROWTYPE; _allocation structs.allocation%ROWTYPE;
    _first CHARACTER VARYING; _second CHARACTER VARYING; _guild CHARACTER VARYING;
    _source CHARACTER VARYING; _station CHARACTER VARYING; _target CHARACTER VARYING;
BEGIN
    SELECT * INTO _tx FROM signer.tx WHERE id=_tx_id;
    IF NOT FOUND OR _tx.contract IS DISTINCT FROM 'v022-1' OR _tx.module<>'structs'
        OR signer.ENERGY_REQUEST_VALID(_tx.command::text,_tx.args,_tx.flags) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
    IF NOT EXISTS (SELECT 1 FROM structs.player_address WHERE address=_address AND player_id=_tx.requested_player_id AND status='approved') THEN RETURN FALSE; END IF;
    _first:=_tx.args->>0; _second:=_tx.args->>1;
    IF _tx.command<>'substation-player-disconnect' AND _tx.object_id IS DISTINCT FROM _first THEN RETURN FALSE; END IF;
    CASE _tx.command::text
        WHEN 'allocation-create' THEN
            _guild:=signer.ALLOCATION_SOURCE_GUILD(_first);
            RETURN signer.PERMISSION_CHECK(_address,_first,256) IS TRUE
                AND (split_part(_first,'-',1)<>'4' OR EXISTS (SELECT 1 FROM structs.substation WHERE id=_first AND deletion_pending IS FALSE))
                AND (EXISTS (SELECT 1 FROM structs.player WHERE id=_tx.flags->>'controller')
                    OR EXISTS (SELECT 1 FROM structs.guild WHERE id=_tx.flags->>'controller'))
                AND (_guild IS NULL OR _guild=_tx.flags->>'controller' OR signer.PERMISSION_CHECK(_address,_first,2) IS TRUE);
        WHEN 'allocation-delete','allocation-update','allocation-transfer','substation-allocation-connect','substation-allocation-disconnect' THEN
            SELECT * INTO _allocation FROM structs.allocation WHERE id=_first;
            IF NOT FOUND THEN RETURN FALSE; END IF;
            CASE _tx.command::text
                WHEN 'allocation-delete' THEN
                    RETURN (signer.PERMISSION_CHECK(_address,_allocation.source_id,256) IS TRUE OR signer.PERMISSION_CHECK(_address,_first,8) IS TRUE)
                        AND (_allocation.allocation_type='dynamic' OR (_allocation.allocation_type IN ('static','automated')
                            AND signer.ALLOCATION_SOURCE_GUILD(_allocation.source_id) IS NOT NULL
                            AND signer.PERMISSION_CHECK(_address,_allocation.source_id,2) IS TRUE));
                WHEN 'allocation-update' THEN RETURN _allocation.allocation_type='dynamic' AND signer.PERMISSION_CHECK(_address,_allocation.source_id,256) IS TRUE;
                WHEN 'allocation-transfer' THEN RETURN signer.PERMISSION_CHECK(_address,_first,2) IS TRUE
                    AND (EXISTS (SELECT 1 FROM structs.player WHERE id=_second) OR EXISTS (SELECT 1 FROM structs.guild WHERE id=_second));
                WHEN 'substation-allocation-connect' THEN RETURN signer.PERMISSION_CHECK(_address,_first,2048) IS TRUE
                    AND _allocation.source_id IS DISTINCT FROM _second AND _allocation.destination_id IS DISTINCT FROM _second
                    AND EXISTS (SELECT 1 FROM structs.substation WHERE id=_second AND deletion_pending IS FALSE);
                WHEN 'substation-allocation-disconnect' THEN RETURN signer.PERMISSION_CHECK(_address,_first,2048) IS TRUE
                    OR signer.PERMISSION_CHECK(_address,_allocation.destination_id,2048) IS TRUE;
            END CASE;
        WHEN 'substation-create' THEN
            RETURN (EXISTS (SELECT 1 FROM structs.player WHERE id=_first)
                OR (EXISTS (SELECT 1 FROM structs.guild WHERE id=_first) AND signer.PERMISSION_CHECK(_address,_first,2048) IS TRUE))
                AND signer.PERMISSION_CHECK(_address,_second,2048) IS TRUE;
        WHEN 'substation-delete' THEN
            RETURN signer.PERMISSION_CHECK(_address,_first,8) IS TRUE
                AND (_second='' OR signer.STATION_CONNECTION_CHECK(_address,_second));
        WHEN 'substation-player-connect' THEN
            RETURN signer.STATION_CONNECTION_CHECK(_address,_first) AND signer.PERMISSION_CHECK(_address,_second,1024) IS TRUE;
        WHEN 'substation-player-disconnect' THEN
            SELECT substation_id INTO _station FROM structs.player WHERE id=_first;
            RETURN _station IS NOT DISTINCT FROM _tx.object_id AND EXISTS (SELECT 1 FROM structs.substation WHERE id=_station)
                AND (signer.PERMISSION_CHECK(_address,_first,1024) IS TRUE OR signer.STATION_CONNECTION_CHECK(_address,_station));
        WHEN 'substation-player-migrate' THEN
            IF NOT signer.STATION_CONNECTION_CHECK(_address,_first) THEN RETURN FALSE; END IF;
            FOREACH _target IN ARRAY string_to_array(_second,',') LOOP
                IF signer.PERMISSION_CHECK(_address,_target,1024) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
            END LOOP;
            RETURN TRUE;
        WHEN 'substation-update-name','substation-update-pfp' THEN RETURN signer.UGC_PERMISSION_CHECK(_address,_first);
    END CASE;
    RETURN FALSE;
END
$BODY$;

CREATE FUNCTION signer.CREATE_ENERGY_TRANSACTION_V022(_player_id CHARACTER VARYING,_object_id CHARACTER VARYING,
    _command structs.signer_tx_type,_args JSONB,_flags JSONB)
RETURNS VOID LANGUAGE plpgsql VOLATILE AS $BODY$
BEGIN
    IF signer.ENERGY_REQUEST_VALID(_command::text,_args,_flags) IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'invalid energy transaction arguments' USING ERRCODE='22023';
    END IF;
    IF _command='substation-player-disconnect' AND NOT signer.ENERGY_ID_VALID(_object_id,ARRAY['4']) THEN
        RAISE EXCEPTION 'disconnect requires the expected current substation' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_object_id,'structs',_command,_args,_flags,
        jsonb_build_array(jsonb_build_object('check_type','energy','object_id',_object_id,'permission',0)));
END
$BODY$;
REVOKE ALL ON FUNCTION signer.CREATE_ENERGY_TRANSACTION_V022(CHARACTER VARYING,CHARACTER VARYING,structs.signer_tx_type,JSONB,JSONB) FROM PUBLIC;

CREATE OR REPLACE FUNCTION signer.tx_allocation_create(_player_id VARCHAR,_allocation_type VARCHAR,_source_id VARCHAR,_amount NUMERIC,_controller VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
DECLARE _selected VARCHAR;
BEGIN
    _selected:=COALESCE(NULLIF(_controller,''),signer.ALLOCATION_SOURCE_GUILD(_source_id),_player_id);
    _selected:=signer.SELECT_ASSET_OWNER(_player_id,_selected);
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_source_id,'allocation-create',jsonb_build_array(_source_id,signer.UINT64_ARGUMENT(_amount,'allocation power',_allocation_type='automated')),jsonb_build_object('allocation-type',CASE WHEN _allocation_type='providerAgreement' THEN 'provider-agreement' ELSE _allocation_type END,'controller',_selected));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_allocation_create(_allocation_type VARCHAR,_source_id VARCHAR,_amount NUMERIC,_controller VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    RAISE EXCEPTION 'requested signing player is required; use the overload with player_id first' USING ERRCODE='22023';
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_allocation_connect(_player_id VARCHAR,_allocation_id VARCHAR,_substation_id VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_allocation_id,'substation-allocation-connect',jsonb_build_array(_allocation_id,_substation_id),'{}'::jsonb);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_allocation_delete(_player_id VARCHAR,_allocation_id VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_allocation_id,'allocation-delete',jsonb_build_array(_allocation_id),'{}'::jsonb);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_allocation_disconnect(_player_id VARCHAR,_allocation_id VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_allocation_id,'substation-allocation-disconnect',jsonb_build_array(_allocation_id),'{}'::jsonb);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_allocation_transfer(_player_id VARCHAR,_allocation_id VARCHAR,_controller VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_allocation_id,'allocation-transfer',jsonb_build_array(_allocation_id,_controller),'{}'::jsonb);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_allocation_update(_player_id VARCHAR,_allocation_id VARCHAR,_power NUMERIC)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_allocation_id,'allocation-update',jsonb_build_array(_allocation_id,signer.UINT64_ARGUMENT(_power,'allocation power',FALSE)),'{}'::jsonb);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_substation_delete(_player_id VARCHAR,_substation_id VARCHAR,_migration_substation_id VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_substation_id,'substation-delete',jsonb_build_array(_substation_id,COALESCE(_migration_substation_id,'')),'{}'::jsonb);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_substation_player_connect(_player_id VARCHAR,_substation_id VARCHAR,_target_player_id VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_substation_id,'substation-player-connect',jsonb_build_array(_substation_id,_target_player_id),'{}'::jsonb);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_substation_player_disconnect(_player_id VARCHAR,_substation_id VARCHAR,_target_player_id VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_substation_id,'substation-player-disconnect',jsonb_build_array(_target_player_id),'{}'::jsonb);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_substation_update_name(_player_id VARCHAR,_substation_id VARCHAR,_name VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_substation_id,'substation-update-name',jsonb_build_array(_substation_id,_name),'{}'::jsonb);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_substation_update_pfp(_player_id VARCHAR,_substation_id VARCHAR,_pfp VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_substation_id,'substation-update-pfp',jsonb_build_array(_substation_id,_pfp),'{}'::jsonb);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_substation_create(_player_id VARCHAR,_allocation_id VARCHAR,_owner_id VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
DECLARE _selected VARCHAR;
BEGIN
    _selected:=signer.SELECT_ASSET_OWNER(_player_id,_owner_id);
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_selected,'substation-create',jsonb_build_array(_selected,_allocation_id),'{}'::jsonb);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_substation_create(_player_id VARCHAR,_allocation_id VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.tx_substation_create(_player_id,_allocation_id,_player_id);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_substation_player_disconnect(_substation_id VARCHAR,_target_player_id VARCHAR)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    RAISE EXCEPTION 'requested signing player is required; use the overload with player_id first' USING ERRCODE='22023';
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_substation_player_migrate(_player_id VARCHAR,_substation_id VARCHAR,_target_player_ids VARCHAR[])
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    IF COALESCE(array_ndims(_target_player_ids),0)<>1 THEN
        RAISE EXCEPTION 'migration requires a nonempty, one-dimensional player list' USING ERRCODE='22023';
    END IF;
    IF array_position(_target_player_ids,NULL) IS NOT NULL THEN
        RAISE EXCEPTION 'migration requires a nonempty, one-dimensional player list' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_ENERGY_TRANSACTION_V022(_player_id,_substation_id,'substation-player-migrate',jsonb_build_array(_substation_id,array_to_string(_target_player_ids,',')),'{}'::jsonb);
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
      AND CASE WHEN t.command::text LIKE 'allocation-%' OR t.command::text LIKE 'substation-%'
          THEN EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id
              AND rule.check_type='energy' AND rule.object_id=t.object_id) ELSE TRUE END
      AND (t.command<>'address-register' OR signer.REGISTRATION_CONTEXT_CHECK(t.id))
      AND (t.command NOT IN ('address-revoke','player-update-primary-address') OR signer.ADDRESS_MANAGEMENT_CHECK(t.id))
      AND EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id)
      AND NOT EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id
          AND (CASE WHEN rule.check_type='energy' THEN
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
        ('signer.tx_allocation_create(character varying,character varying,numeric,character varying)','signer.tx_allocation_create(character varying,character varying,character varying,numeric,character varying)'),
        ('signer.tx_substation_create(character varying,character varying)','signer.tx_substation_create(character varying,character varying,character varying)'),
        ('signer.tx_substation_player_disconnect(character varying,character varying)','signer.tx_substation_player_disconnect(character varying,character varying,character varying)')
    ) v(source,target) JOIN pg_proc p ON p.oid=to_regprocedure(v.source)
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
