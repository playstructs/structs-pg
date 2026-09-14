-- Deploy structs-pg:cagg-planet-activity-20260915-hourly to pg
--
-- Hourly activity counts per (category, planet) as a Timescale continuous
-- aggregate. This replaces GROUP BY over raw planet_activity on request paths
-- (planetActivityStats scans 30 days of rows per call today, ~580 ms) and is
-- the base for the daily rollup in cagg-planet-activity-20260915-daily.
--
-- materialized_only = true: reads never touch the raw hypertable; the policy
-- refreshes every 10 minutes, so counts lag by at most ~10 minutes. Global
-- per-category stats are SUM(count) over planet_id.
--
-- The initial refresh runs outside the transaction (refresh_continuous_aggregate
-- cannot run inside one); Sqitch runs deploy scripts through psql without
-- --single-transaction so the CALL commits on its own.

BEGIN;

    CREATE MATERIALIZED VIEW structs.planet_activity_hourly
    WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
        SELECT time_bucket(INTERVAL '1 hour', pa.time) AS bucket,
               pa.category,
               pa.planet_id,
               count(*)::BIGINT AS count
          FROM structs.planet_activity pa
         GROUP BY 1, 2, 3
    WITH NO DATA;

    COMMENT ON VIEW structs.planet_activity_hourly IS
        'Continuous aggregate: planet_activity rows per hour, category and planet. Materialized only; refreshed every 10 minutes. Sum over planet_id for global stats.';

    SELECT add_continuous_aggregate_policy(
        'structs.planet_activity_hourly',
        start_offset      => INTERVAL '3 days',
        end_offset        => INTERVAL '10 minutes',
        schedule_interval => INTERVAL '10 minutes'
    );

    GRANT SELECT ON structs.planet_activity_hourly TO structs_webapp;
    GRANT SELECT ON structs.planet_activity_hourly TO structs_indexer;

COMMIT;

CALL refresh_continuous_aggregate('structs.planet_activity_hourly', NULL, NULL);
