-- Verify structs-pg:role-structs-webapp-20261030-gameplay-reads on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
DO $$
DECLARE
    relation regclass;
BEGIN
    FOREACH relation IN ARRAY ARRAY['structs.planet_raid',
        'structs.planet_attribute',
        'structs.planet_activity',
        'view.struct_status',
        'structs.address_tag',
        'structs.banned_word',
        'structs.guild_membership_application',
        'structs.stat_capacity',
        'structs.stat_connection_capacity',
        'structs.stat_connection_count',
        'structs.stat_fuel',
        'structs.stat_load',
        'structs.stat_ore',
        'structs.stat_power',
        'structs.stat_struct_health',
        'structs.stat_struct_status',
        'structs.stat_structs_load']::regclass[] LOOP
        EXECUTE format('SELECT * FROM %s LIMIT 0', relation);
        -- Inspect ACLs even on legacy installations where the role is superuser.
        IF NOT EXISTS (SELECT 1 FROM pg_class c,
            LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a
            WHERE c.oid=relation AND a.grantee=current_user::regrole::oid
                AND a.privilege_type='SELECT')
            OR EXISTS (SELECT 1 FROM pg_class c,
                LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a
                WHERE c.oid=relation AND a.grantee IN (0,current_user::regrole::oid)
                    AND a.privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE'))
            OR (NOT (SELECT rolsuper FROM pg_roles WHERE rolname=current_user)
                AND has_table_privilege(current_user,relation,'INSERT,UPDATE,DELETE,TRUNCATE')) THEN
            RAISE EXCEPTION 'webapp gameplay relation % must remain read-only', relation;
        END IF;
    END LOOP;
END;
$$;
ROLLBACK;
