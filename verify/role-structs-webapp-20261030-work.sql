-- Verify structs-pg:role-structs-webapp-20261030-work on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
SELECT object_id,player_id,target_id,category,block_start,difficulty_target,
    location_type,location_id,planet_id FROM view.work LIMIT 0;
DO $$
BEGIN
    -- Relation ACLs are the migration contract; legacy superuser status is an
    -- independent deployment concern, not evidence of a write GRANT here.
    IF NOT EXISTS (SELECT 1 FROM pg_class c,
        LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a
        WHERE c.oid='view.work'::regclass AND a.grantee=current_user::regrole::oid
            AND a.privilege_type='SELECT')
        OR EXISTS (SELECT 1 FROM pg_class c,
            LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a
            WHERE c.oid IN ('view.work'::regclass,'structs.api_work'::regclass)
                AND a.grantee IN (0,current_user::regrole::oid)
                AND a.privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE'))
        OR (NOT (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) AND (
            has_table_privilege(current_user,'view.work','INSERT,UPDATE,DELETE')
            OR has_table_privilege(current_user,'structs.api_work','INSERT,UPDATE,DELETE,TRUNCATE'))) THEN
        RAISE EXCEPTION 'webapp work grants must remain read-only';
    END IF;
END;
$$;
ROLLBACK;
