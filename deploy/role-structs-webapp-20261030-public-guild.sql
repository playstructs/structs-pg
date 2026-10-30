-- Deploy structs-pg:role-structs-webapp-20261030-public-guild to pg
BEGIN;
-- Existing guild directory and power statistics queries use these views.
GRANT SELECT ON view.player,view.reactor TO structs_webapp;
COMMIT;
