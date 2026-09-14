-- Revert structs-pg:cagg-planet-activity-20260915-hourly from pg
--
-- Dropping the continuous aggregate removes its refresh policy and
-- materialization hypertable.

BEGIN;

    DROP MATERIALIZED VIEW IF EXISTS structs.planet_activity_hourly;

COMMIT;
