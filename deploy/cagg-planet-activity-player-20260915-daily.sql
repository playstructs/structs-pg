-- Deploy structs-pg:cagg-planet-activity-player-20260915-daily to pg
--
-- Per-player daily activity counts by category and role, as a continuous
-- aggregate on structs.planet_activity_player. This is the per-player stats
-- source (attacks made / taken, raids, builds per day) that has no equivalent
-- today because attribution only existed at read time.
--
-- materialized_only = false: the current day is served by real-time
-- aggregation over planet_activity_player rows newer than the watermark,
-- bounded by time (primary key leads on time), so it stays cheap.

BEGIN;

    CREATE MATERIALIZED VIEW structs.planet_activity_player_daily
    WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
        SELECT time_bucket(INTERVAL '1 day', pap.time) AS bucket,
               pap.player_id,
               pap.category,
               pap.role,
               count(*)::BIGINT AS count
          FROM structs.planet_activity_player pap
         GROUP BY 1, 2, 3, 4
    WITH NO DATA;

    COMMENT ON VIEW structs.planet_activity_player_daily IS
        'Continuous aggregate: planet_activity_player rows per day, player, category and role. Real-time for the current day.';

    SELECT add_continuous_aggregate_policy(
        'structs.planet_activity_player_daily',
        start_offset      => INTERVAL '7 days',
        end_offset        => INTERVAL '1 hour',
        schedule_interval => INTERVAL '1 hour'
    );

    GRANT SELECT ON structs.planet_activity_player_daily TO structs_webapp;
    GRANT SELECT ON structs.planet_activity_player_daily TO structs_indexer;

COMMIT;

CALL refresh_continuous_aggregate('structs.planet_activity_player_daily', NULL, NULL);
