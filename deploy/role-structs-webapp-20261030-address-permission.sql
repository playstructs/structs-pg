-- Deploy structs-pg:role-structs-webapp-20261030-address-permission to pg
BEGIN;
-- Device transaction completion compares native authority with its indexed
-- projection. Only sync-state may write this chain-owned permission table.
GRANT SELECT ON structs.permission TO structs_webapp;
COMMIT;
