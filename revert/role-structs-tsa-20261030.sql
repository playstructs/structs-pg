-- Revert structs-pg:role-structs-tsa-20261030 from pg
BEGIN;
DROP FUNCTION signer.WORKER_AUTHORIZED_ACCOUNTS_V022(INTEGER);
DROP FUNCTION signer.BIND_REQUEST_ACCOUNT_V022(INTEGER,VARCHAR);
DROP FUNCTION signer.INVALIDATE_LOCAL_KEY_V022(UUID,VARCHAR);
DO $$ DECLARE f RECORD; setting TEXT; a RECORD; target REGPROCEDURE; grantee_name TEXT; owner_id OID; BEGIN
    FOR f IN SELECT * FROM signer.worker_function_settings LOOP
        target := f.identity::regprocedure;
        EXECUTE format('ALTER FUNCTION %s SECURITY %s',target,CASE WHEN f.security_definer THEN 'DEFINER' ELSE 'INVOKER' END);
        EXECUTE format('ALTER FUNCTION %s RESET ALL',target);
        FOREACH setting IN ARRAY COALESCE(f.configuration,ARRAY[]::text[]) LOOP
            PERFORM set_config(split_part(setting,'=',1),substring(setting from position('=' in setting)+1),TRUE);
            EXECUTE format('ALTER FUNCTION %s SET %I FROM CURRENT',target,split_part(setting,'=',1));
        END LOOP;
        SELECT p.proowner INTO owner_id FROM pg_proc p WHERE p.oid=target;
        FOR a IN SELECT acl.* FROM pg_proc p,LATERAL aclexplode(COALESCE(p.proacl,acldefault('f',p.proowner))) acl WHERE p.oid=target LOOP
            grantee_name := CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(a.grantee)) END;
            EXECUTE format('REVOKE ALL ON FUNCTION %s FROM %s',target,grantee_name);
        END LOOP;
        FOR a IN SELECT * FROM aclexplode(COALESCE(f.privileges,acldefault('f',owner_id))) LOOP
            grantee_name := CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(a.grantee)) END;
            EXECUTE format('GRANT %s ON FUNCTION %s TO %s%s',a.privilege_type,target,grantee_name,
                CASE WHEN a.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
        END LOOP;
    END LOOP;
END $$;
DROP TABLE signer.worker_function_settings;
REVOKE SELECT ON signer.tx,signer.account,signer.role,signer.tx_submission,signer.account_request,
    signer.local_key,signer.role_key_request FROM structs_tsa;
REVOKE SELECT(id,val) ON structs.permission FROM structs_tsa;
REVOKE SELECT(role_id) ON structs.player_internal_pending FROM structs_tsa;
REVOKE EXECUTE ON FUNCTION structs.api_readiness(TEXT[]) FROM structs_tsa;
REVOKE USAGE ON SCHEMA signer,structs FROM structs_tsa;
-- Retain the cluster-level login: another database may use it or have a
-- separately configured password. No game or signing history is deleted.
COMMIT;
