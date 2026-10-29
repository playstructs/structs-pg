-- Deploy structs-pg:role-structs-webapp-20261029-funds to pg
BEGIN;
-- Exact sources read by existing player/transfer-search queries. The restricted
-- role must work without relying on a superuser service connection.
GRANT USAGE ON SCHEMA view TO structs_webapp;
GRANT SELECT ON structs.fleet,structs.grid,structs.guild_meta,structs.player_address,
    view.player_inventory TO structs_webapp;
COMMIT;
