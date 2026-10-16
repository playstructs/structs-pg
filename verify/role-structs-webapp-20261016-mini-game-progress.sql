-- Verify structs-pg:role-structs-webapp-20261016-mini-game-progress on pg

BEGIN;

    DO $$
    DECLARE
        direct_privileges integer;
    BEGIN
        SELECT count(*) INTO direct_privileges
          FROM pg_class c
          CROSS JOIN LATERAL aclexplode(c.relacl) acl
         WHERE c.oid = 'structs.mini_game_progress'::regclass
           AND acl.grantee = 'structs_webapp'::regrole
           AND acl.privilege_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE');

        IF direct_privileges <> 4 THEN
            RAISE EXCEPTION 'structs_webapp lacks full DML on structs.mini_game_progress';
        END IF;
    END
    $$;

ROLLBACK;
