-- Deploy structs-pg:cagg-planet-activity-20260915-daily to pg
--
-- Daily activity counts per (category, planet), as a hierarchical continuous
-- aggregate on structs.planet_activity_hourly.
--
-- materialized_only = false: the current, unfinished day is served by
-- real-time aggregation over the *hourly cagg* (not the raw table), so it is
-- as fresh as the hourly refresh at the cost of a few hundred rows of
-- summation. Finished days are materialized by the policy.

BEGIN;

    CREATE MATERIALIZED VIEW structs.planet_activity_daily
    WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
        SELECT time_bucket(INTERVAL '1 day', h.bucket) AS bucket,
               h.category,
               h.planet_id,
               sum(h.count)::BIGINT AS count
          FROM structs.planet_activity_hourly h
         GROUP BY 1, 2, 3
    WITH NO DATA;

    COMMENT ON VIEW structs.planet_activity_daily IS
        'Continuous aggregate on planet_activity_hourly: rows per day, category and planet. Real-time for the current day. Sum over planet_id for global stats.';

    SELECT add_continuous_aggregate_policy(
        'structs.planet_activity_daily',
        start_offset      => INTERVAL '7 days',
        end_offset        => INTERVAL '1 hour',
        schedule_interval => INTERVAL '1 hour'
    );

    GRANT SELECT ON structs.planet_activity_daily TO structs_webapp;
    GRANT SELECT ON structs.planet_activity_daily TO structs_indexer;

COMMIT;

CALL refresh_continuous_aggregate('structs.planet_activity_daily', NULL, NULL);
