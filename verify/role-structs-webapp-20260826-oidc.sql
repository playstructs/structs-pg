-- Verify structs-pg:role-structs-webapp-20260826-oidc on pg

BEGIN;

    DO $$
    DECLARE
        table_name text;
        direct_privileges integer;
    BEGIN
        FOREACH table_name IN ARRAY ARRAY[
            'oidc_client',
            'oidc_authorization_request',
            'oidc_authorization_code',
            'oidc_access_token'
        ]
        LOOP
            SELECT count(*) INTO direct_privileges
              FROM pg_class c
              CROSS JOIN LATERAL aclexplode(c.relacl) acl
             WHERE c.oid = ('structs.' || table_name)::regclass
               AND acl.grantee = 'structs_webapp'::regrole
               AND acl.privilege_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE');
            IF direct_privileges <> 4 THEN
                RAISE EXCEPTION 'structs_webapp lacks full DML on structs.%', table_name;
            END IF;
        END LOOP;
    END
    $$;

ROLLBACK;
