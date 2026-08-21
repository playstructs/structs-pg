-- Verify structs-pg:role-structs-webapp-20260820-api-read on pg

BEGIN;

    DO $$
    DECLARE
        table_name text;
        direct_privileges integer;
    BEGIN
        FOREACH table_name IN ARRAY ARRAY[
            'api_refresh_state',
            'api_leaderboard_player',
            'api_leaderboard_guild',
            'api_leaderboard_reactor',
            'api_leaderboard_substation',
            'api_leaderboard_provider',
            'api_inventory',
            'api_guild_bank'
        ]
        LOOP
            SELECT count(*) INTO direct_privileges
              FROM pg_class c
              CROSS JOIN LATERAL aclexplode(c.relacl) acl
             WHERE c.oid = ('structs.' || table_name)::regclass
               AND acl.grantee = 'structs_webapp'::regrole
               AND acl.privilege_type = 'SELECT';
            IF direct_privileges <> 1 THEN
                RAISE EXCEPTION 'structs_webapp lacks SELECT on structs.%', table_name;
            END IF;

            SELECT count(*) INTO direct_privileges
              FROM pg_class c
              CROSS JOIN LATERAL aclexplode(c.relacl) acl
             WHERE c.oid = ('structs.' || table_name)::regclass
               AND acl.grantee = 'structs_webapp'::regrole
               AND acl.privilege_type IN ('INSERT', 'UPDATE', 'DELETE');
            IF direct_privileges <> 0 THEN
                RAISE EXCEPTION 'structs_webapp has write access on structs.%', table_name;
            END IF;
        END LOOP;
    END
    $$;

ROLLBACK;
