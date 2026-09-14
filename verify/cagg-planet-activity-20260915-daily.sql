-- Verify structs-pg:cagg-planet-activity-20260915-daily on pg

BEGIN;

    SELECT bucket, category, planet_id, count FROM structs.planet_activity_daily WHERE FALSE;

    DO $$
    DECLARE
        v_day  TIMESTAMPTZ := (date_trunc('day', now() AT TIME ZONE 'UTC' - INTERVAL '2 days')) AT TIME ZONE 'UTC'; -- a UTC-midnight bucket boundary
        v_hourly BIGINT;
        v_daily  BIGINT;
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM timescaledb_information.continuous_aggregates
             WHERE view_schema = 'structs' AND view_name = 'planet_activity_daily'
        ) THEN
            RAISE EXCEPTION 'structs.planet_activity_daily is not a continuous aggregate';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM timescaledb_information.jobs j
             WHERE j.hypertable_schema = 'structs' AND j.hypertable_name = 'planet_activity_daily'
               AND j.proc_name = 'policy_refresh_continuous_aggregate'
        ) THEN
            RAISE EXCEPTION 'no refresh policy on structs.planet_activity_daily';
        END IF;

        SELECT COALESCE(sum(count), 0) INTO v_hourly
          FROM structs.planet_activity_hourly
         WHERE bucket >= v_day AND bucket < v_day + INTERVAL '1 day';

        SELECT COALESCE(sum(count), 0) INTO v_daily
          FROM structs.planet_activity_daily
         WHERE bucket = v_day;

        IF v_hourly <> v_daily THEN
            RAISE EXCEPTION 'planet_activity_daily disagrees with hourly for %: hourly % vs daily %', v_day, v_hourly, v_daily;
        END IF;
    END
    $$;

ROLLBACK;
