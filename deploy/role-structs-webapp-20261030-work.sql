-- Deploy structs-pg:role-structs-webapp-20261030-work to pg
BEGIN;
-- Existing work restoration and reconciliation read the maintained projection.
-- The webapp does not write clocks, difficulty or worker source watermarks.
GRANT SELECT ON view.work TO structs_webapp;
COMMIT;
