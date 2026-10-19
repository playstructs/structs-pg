-- Verify structs-pg:role-structs-webapp-20261019-onboarding on pg

BEGIN;

    DO $$
    DECLARE
        privileges integer;
    BEGIN
        SELECT count(*) INTO privileges
          FROM pg_class c
          CROSS JOIN LATERAL aclexplode(c.relacl) acl
         WHERE c.oid = 'structs.onboarding_step'::regclass
           AND acl.grantee = 'structs_webapp'::regrole
           AND acl.privilege_type = 'SELECT';
        IF privileges <> 1 THEN
            RAISE EXCEPTION 'structs_webapp must have SELECT on structs.onboarding_step';
        END IF;

        IF EXISTS (
            SELECT 1
              FROM pg_class c
              CROSS JOIN LATERAL aclexplode(c.relacl) acl
             WHERE c.oid = 'structs.onboarding_step'::regclass
               AND acl.grantee = 'structs_webapp'::regrole
               AND acl.privilege_type IN ('INSERT', 'UPDATE', 'DELETE')
        ) THEN
            RAISE EXCEPTION 'structs_webapp must not write structs.onboarding_step';
        END IF;

        SELECT count(*) INTO privileges
          FROM pg_class c
          CROSS JOIN LATERAL aclexplode(c.relacl) acl
         WHERE c.oid IN ('structs.onboarding_session'::regclass, 'structs.onboarding_progress'::regclass)
           AND acl.grantee = 'structs_webapp'::regrole
           AND acl.privilege_type IN ('SELECT', 'INSERT');
        IF privileges <> 4 THEN
            RAISE EXCEPTION 'structs_webapp must have SELECT and INSERT on onboarding_session and onboarding_progress';
        END IF;

        IF EXISTS (
            SELECT 1
              FROM pg_class c
              CROSS JOIN LATERAL aclexplode(c.relacl) acl
             WHERE c.oid IN ('structs.onboarding_session'::regclass, 'structs.onboarding_progress'::regclass)
               AND acl.grantee = 'structs_webapp'::regrole
               AND acl.privilege_type IN ('UPDATE', 'DELETE')
        ) THEN
            RAISE EXCEPTION 'structs_webapp must not update or delete onboarding_session or onboarding_progress';
        END IF;
    END
    $$;

ROLLBACK;
