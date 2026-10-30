-- Verify structs-pg:role-structs-webapp-20261030-device-metadata on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
SELECT address,player_id,block_time FROM structs.player_address_activity LIMIT 0;
SELECT address,ip,user_agent,updated_at FROM structs.player_address_meta LIMIT 0;
SELECT address,denom,balance FROM view.address_inventory LIMIT 0;
DO $$
BEGIN
    IF NOT has_table_privilege(current_user,'structs.player_address_meta','INSERT')
        OR NOT has_table_privilege(current_user,'structs.player_address_meta','UPDATE')
        OR has_table_privilege(current_user,'structs.player_address_meta','DELETE,TRUNCATE')
        OR has_table_privilege(current_user,'structs.player_address_activity','INSERT,UPDATE,DELETE,TRUNCATE')
        OR has_table_privilege(current_user,'view.address_inventory','INSERT,UPDATE,DELETE') THEN
        RAISE EXCEPTION 'incorrect webapp device metadata privileges';
    END IF;
END;
$$;
ROLLBACK;
