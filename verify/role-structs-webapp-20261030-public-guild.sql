-- Verify structs-pg:role-structs-webapp-20261030-public-guild on pg
BEGIN;
SET LOCAL ROLE structs_webapp;
SELECT player_id,total_load,total_capacity,connection_capacity,
    total_load_p,total_capacity_p,connection_capacity_p FROM view.player LIMIT 0;
SELECT reactor_id,guild_id,fuel FROM view.reactor LIMIT 0;
ROLLBACK;
