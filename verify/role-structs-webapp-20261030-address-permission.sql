-- Verify structs-pg:role-structs-webapp-20261030-address-permission on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
SELECT object_id,object_type,object_index,player_id,val::text
FROM structs.permission LIMIT 0;
DO $$
BEGIN
    -- Legacy images create this service role as a superuser. This change owns
    -- relation grants, not cluster-wide role attributes (as with economy-contract).
    IF NOT EXISTS (SELECT 1 FROM pg_class c,
        LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a
        WHERE c.oid='structs.permission'::regclass AND a.grantee=current_user::regrole::oid
            AND a.privilege_type='SELECT')
        OR EXISTS (SELECT 1 FROM pg_class c,
            LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a
            WHERE c.oid='structs.permission'::regclass
                AND a.grantee IN (0,current_user::regrole::oid)
                AND a.privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE'))
        OR (NOT (SELECT rolsuper FROM pg_roles WHERE rolname=current_user)
            AND has_table_privilege(current_user,'structs.permission','INSERT,UPDATE,DELETE,TRUNCATE')) THEN
        RAISE EXCEPTION 'webapp permission projection grants must be read-only';
    END IF;
END;
$$;
ROLLBACK;
