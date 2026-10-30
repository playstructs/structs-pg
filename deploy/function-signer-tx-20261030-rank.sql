-- Deploy structs-pg:function-signer-tx-20261030-rank to pg
BEGIN;
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'rank wrappers require the coordinated v022-1 signer contract';
    END IF;
END $$;

CREATE FUNCTION signer.PERMISSION_ARGUMENT(_value NUMERIC,_allow_zero BOOLEAN DEFAULT FALSE)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $BODY$
DECLARE _argument TEXT;
BEGIN
    _argument := signer.UINT64_ARGUMENT(_value,'permission',_allow_zero);
    IF _value>33554431 THEN
        RAISE EXCEPTION 'permission contains undefined bits' USING ERRCODE='22023';
    END IF;
    RETURN _argument;
END
$BODY$;

CREATE FUNCTION signer.SELECT_SIGNING_GUILD(_player_id CHARACTER VARYING,_guild_id CHARACTER VARYING)
RETURNS CHARACTER VARYING LANGUAGE plpgsql STABLE AS $BODY$
DECLARE _selected CHARACTER VARYING := NULLIF(_guild_id,'');
BEGIN
    IF _selected IS NULL THEN
        SELECT guild_id INTO _selected FROM structs.player WHERE id=_player_id;
    END IF;
    IF _selected IS NULL OR NOT EXISTS (SELECT 1 FROM structs.guild WHERE id=_selected) THEN
        RAISE EXCEPTION 'signing guild does not exist' USING ERRCODE='22023';
    END IF;
    RETURN _selected;
END
$BODY$;

CREATE TEMP TABLE signer_rank_entry_acl ON COMMIT DROP AS
    SELECT proowner,proacl FROM pg_proc WHERE oid='signer.tx_guild_update_entry_rank(character varying,character varying,bigint)'::regprocedure;
DROP FUNCTION signer.tx_guild_update_entry_rank(character varying,character varying,bigint);


CREATE OR REPLACE FUNCTION signer.tx_guild_update_entry_rank(_player_id CHARACTER VARYING,_guild_id CHARACTER VARYING,_new_entry_rank NUMERIC)
RETURNS void AS $BODY$
DECLARE _selected CHARACTER VARYING;
BEGIN
    _selected := signer.SELECT_SIGNING_GUILD(_player_id,_guild_id);
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_selected,'structs','guild-update-entry-rank',
        jsonb_build_array(signer.UINT64_ARGUMENT(_new_entry_rank,'entry rank',FALSE)),
        jsonb_build_object('guild-id',_selected),
        jsonb_build_array(jsonb_build_object('check_type','object','object_id',_selected,'permission',2)));
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_player_update_guild_rank(_player_id CHARACTER VARYING,_target_player_id CHARACTER VARYING,
    _guild_rank NUMERIC,_guild_id CHARACTER VARYING)
RETURNS void AS $BODY$
DECLARE _selected CHARACTER VARYING;
BEGIN
    _selected := signer.SELECT_SIGNING_GUILD(_player_id,_guild_id);
    IF NOT EXISTS (SELECT 1 FROM structs.player WHERE id=_target_player_id AND guild_id=_selected) THEN
        RAISE EXCEPTION 'target player does not belong to the selected guild' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_selected,'structs','player-update-guild-rank',
        jsonb_build_array(_target_player_id,signer.UINT64_ARGUMENT(_guild_rank,'player rank',FALSE)),
        jsonb_build_object('guild-id',_selected),
        jsonb_build_array(jsonb_build_object('check_type','object','object_id',_selected,'permission',2)));
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_permission_guild_rank_set(_player_id CHARACTER VARYING,_object_id CHARACTER VARYING,
    _guild_id CHARACTER VARYING,_permission NUMERIC,_rank NUMERIC)
RETURNS void AS $BODY$
DECLARE _permission_argument TEXT;
BEGIN
    _permission_argument := signer.PERMISSION_ARGUMENT(_permission);
    IF NOT EXISTS (SELECT 1 FROM structs.guild WHERE id=_guild_id) THEN
        RAISE EXCEPTION 'permission guild does not exist' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_object_id,'structs','permission-guild-rank-set',
        jsonb_build_array(_object_id,_guild_id,_permission_argument,signer.UINT64_ARGUMENT(_rank,'permission rank',FALSE)),
        '{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_object_id,'permission',2))
            || CASE WHEN _permission=2 THEN '[]'::jsonb ELSE jsonb_build_array(
                jsonb_build_object('check_type','object','object_id',_object_id,'permission',_permission::integer)) END);
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_permission_guild_rank_revoke(_player_id CHARACTER VARYING,_object_id CHARACTER VARYING,
    _guild_id CHARACTER VARYING,_permission NUMERIC)
RETURNS void AS $BODY$
DECLARE _permission_argument TEXT;
BEGIN
    _permission_argument := signer.PERMISSION_ARGUMENT(_permission);
    IF NOT EXISTS (SELECT 1 FROM structs.guild WHERE id=_guild_id) THEN
        RAISE EXCEPTION 'permission guild does not exist' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_object_id,'structs','permission-guild-rank-revoke',
        jsonb_build_array(_object_id,_guild_id,_permission_argument),
        '{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_object_id,'permission',2))
            || CASE WHEN _permission=2 THEN '[]'::jsonb ELSE jsonb_build_array(
                jsonb_build_object('check_type','object','object_id',_object_id,'permission',_permission::integer)) END);
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_player_update_guild_rank(_target_player_id character varying, _guild_rank bigint, _guild_id character varying) RETURNS void AS $BODY$
BEGIN
    RAISE EXCEPTION 'requested signing player is required; use the overload with player_id first' USING ERRCODE='22023';
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_permission_guild_rank_set(_object_id character varying, _guild_id character varying, _permission bigint, _rank bigint) RETURNS void AS $BODY$
BEGIN
    RAISE EXCEPTION 'requested signing player is required; use the overload with player_id first' USING ERRCODE='22023';
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_permission_guild_rank_revoke(_object_id character varying, _guild_id character varying, _permission bigint) RETURNS void AS $BODY$
BEGIN
    RAISE EXCEPTION 'requested signing player is required; use the overload with player_id first' USING ERRCODE='22023';
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

DO $$
DECLARE f RECORD; a RECORD; target REGPROCEDURE; grantee_name TEXT;
BEGIN
    FOR f IN SELECT p.proowner,p.proacl,v.target
        FROM (VALUES
            ('signer.tx_guild_update_entry_rank(character varying,character varying,bigint)','signer.tx_guild_update_entry_rank(character varying,character varying,numeric)'),
            ('signer.tx_player_update_guild_rank(character varying,bigint,character varying)','signer.tx_player_update_guild_rank(character varying,character varying,numeric,character varying)'),
            ('signer.tx_permission_guild_rank_set(character varying,character varying,bigint,bigint)','signer.tx_permission_guild_rank_set(character varying,character varying,character varying,numeric,numeric)'),
            ('signer.tx_permission_guild_rank_revoke(character varying,character varying,bigint)','signer.tx_permission_guild_rank_revoke(character varying,character varying,character varying,numeric)')
        ) v(source,target) JOIN LATERAL (
            SELECT proowner,proacl FROM pg_temp.signer_rank_entry_acl WHERE v.source='signer.tx_guild_update_entry_rank(character varying,character varying,bigint)'
            UNION ALL SELECT proowner,proacl FROM pg_proc WHERE oid=to_regprocedure(v.source)
                AND v.source<>'signer.tx_guild_update_entry_rank(character varying,character varying,bigint)'
        ) p ON TRUE
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
