-- Revert structs-pg:role-structs-webapp-20261029-funds from pg
BEGIN;
REVOKE SELECT ON structs.fleet,structs.grid,structs.guild_meta,structs.player_address,
    view.player_inventory FROM structs_webapp;
REVOKE USAGE ON SCHEMA view FROM structs_webapp;
COMMIT;
