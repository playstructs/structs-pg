-- Verify structs-pg:table-onboarding-20261110-username-exclusion on pg

BEGIN;
SELECT username_regex, reason, created_at FROM structs.onboarding_telemetry_username_exclusion WHERE FALSE;
DO $$
BEGIN
    -- Check explicit grants, as other webapp grant verifiers do. Some
    -- development installations provision the webapp as a superuser.
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c CROSS JOIN LATERAL aclexplode(c.relacl) a
        WHERE c.oid = 'structs.onboarding_telemetry_username_exclusion'::regclass
          AND a.grantee = 'structs_webapp'::regrole AND a.privilege_type = 'SELECT'
    ) OR EXISTS (
        SELECT 1 FROM pg_class c CROSS JOIN LATERAL aclexplode(c.relacl) a
        WHERE c.oid = 'structs.onboarding_telemetry_username_exclusion'::regclass
          AND a.grantee IN (0, 'structs_webapp'::regrole::oid)
          AND a.privilege_type IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
    ) THEN
        RAISE EXCEPTION 'structs_webapp must have read-only grants on onboarding exclusions';
    END IF;
END
$$;
ROLLBACK;
