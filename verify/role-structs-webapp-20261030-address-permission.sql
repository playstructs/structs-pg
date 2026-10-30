-- Verify structs-pg:role-structs-webapp-20261030-address-permission on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
SELECT object_id,object_type,object_index,player_id,val::text
FROM structs.permission LIMIT 0;
DO $$
BEGIN
    IF has_table_privilege(current_user, 'structs.permission', 'INSERT,UPDATE,DELETE,TRUNCATE') THEN
        RAISE EXCEPTION 'webapp must not mutate the indexed permission projection';
    END IF;
END;
$$;
ROLLBACK;
