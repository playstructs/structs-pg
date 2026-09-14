-- Verify structs-pg:role-structs-indexer-20260914-api-work-and-drift on pg

BEGIN;

    DO $$
    DECLARE
        direct_privileges integer;
    BEGIN
        SELECT count(DISTINCT acl.privilege_type) INTO direct_privileges
          FROM pg_class c
          CROSS JOIN LATERAL aclexplode(c.relacl) acl
         WHERE c.oid = 'structs.api_work'::regclass
           AND acl.grantee = 'structs_indexer'::regrole
           AND acl.privilege_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE');
        IF direct_privileges <> 4 THEN
            RAISE EXCEPTION 'structs_indexer lacks DML on structs.api_work';
        END IF;

        SELECT count(DISTINCT acl.privilege_type) INTO direct_privileges
          FROM pg_class c
          CROSS JOIN LATERAL aclexplode(c.relacl) acl
         WHERE c.oid = 'structs.api_inventory_drift'::regclass
           AND acl.grantee = 'structs_indexer'::regrole
           AND acl.privilege_type IN ('SELECT', 'UPDATE', 'DELETE');
        IF direct_privileges <> 3 THEN
            RAISE EXCEPTION 'structs_indexer lacks SELECT/UPDATE/DELETE on structs.api_inventory_drift';
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM pg_proc p
              CROSS JOIN LATERAL aclexplode(p.proacl) acl
             WHERE p.oid = 'structs.api_inventory_reconcile(boolean)'::regprocedure
               AND acl.grantee = 'structs_indexer'::regrole
               AND acl.privilege_type = 'EXECUTE'
        ) THEN
            RAISE EXCEPTION 'structs_indexer lacks EXECUTE on structs.api_inventory_reconcile(boolean)';
        END IF;
    END
    $$;

ROLLBACK;
