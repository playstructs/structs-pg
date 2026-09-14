-- Verify structs-pg:role-structs-webapp-20260914-api-work on pg

BEGIN;

    DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1
              FROM pg_class c
              CROSS JOIN LATERAL aclexplode(c.relacl) acl
             WHERE c.oid = 'structs.api_work'::regclass
               AND acl.grantee = 'structs_webapp'::regrole
               AND acl.privilege_type = 'SELECT'
        ) THEN
            RAISE EXCEPTION 'structs_webapp lacks SELECT on structs.api_work';
        END IF;
    END
    $$;

ROLLBACK;
