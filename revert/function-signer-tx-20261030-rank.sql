-- Revert structs-pg:function-signer-tx-20261030-rank from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.tx IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract='v022-1' AND command IN
        ('guild-update-entry-rank','player-update-guild-rank','permission-guild-rank-set','permission-guild-rank-revoke')) THEN
        RAISE EXCEPTION 'versioned rank requests exist; retain their contract or restore a verified checkpoint';
    END IF;
END $$;
CREATE TEMP TABLE signer_rank_entry_acl ON COMMIT DROP AS
    SELECT proowner,proacl FROM pg_proc WHERE oid='signer.tx_guild_update_entry_rank(character varying,character varying,numeric)'::regprocedure;
CREATE OR REPLACE FUNCTION signer.tx_guild_update_entry_rank(_player_id character varying, _guild_id character varying, _new_entry_rank bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _guild_id,
            32768,
            'structs',
            'guild-update-entry-rank',
            jsonb_build_array(_new_entry_rank),
            jsonb_build_object('guild-id', _guild_id)
        );
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_player_update_guild_rank(_target_player_id character varying, _guild_rank bigint, _guild_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(
            _target_player_id,
            512,
            'structs',
            'player-update-guild-rank',
            jsonb_build_array(_target_player_id, _guild_rank),
            jsonb_build_object('guild-id', _guild_id)
        );
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_permission_guild_rank_set(_object_id character varying, _guild_id character varying, _permission bigint, _rank bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_object_id,2,'structs','permission-guild-rank-set',jsonb_build_array(_object_id, _guild_id, _permission, _rank),'{}');
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_permission_guild_rank_revoke(_object_id character varying, _guild_id character varying, _permission bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_object_id,2,'structs','permission-guild-rank-revoke',jsonb_build_array(_object_id, _guild_id, _permission),'{}');
    END
    $function$
;
DO $$
DECLARE f RECORD; a RECORD; target REGPROCEDURE; grantee_name TEXT;
BEGIN
    FOR f IN SELECT proowner,proacl,'signer.tx_guild_update_entry_rank(character varying,character varying,bigint)' AS target FROM pg_temp.signer_rank_entry_acl
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
DROP FUNCTION signer.tx_guild_update_entry_rank(character varying,character varying,numeric);
DROP FUNCTION signer.tx_player_update_guild_rank(character varying,character varying,numeric,character varying);
DROP FUNCTION signer.tx_permission_guild_rank_set(character varying,character varying,character varying,numeric,numeric);
DROP FUNCTION signer.tx_permission_guild_rank_revoke(character varying,character varying,character varying,numeric);
DROP FUNCTION signer.SELECT_SIGNING_GUILD(character varying,character varying);
DROP FUNCTION signer.PERMISSION_ARGUMENT(numeric,boolean);
COMMIT;
