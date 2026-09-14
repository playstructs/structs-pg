-- Verify structs-pg:cagg-planet-activity-player-20260915-daily on pg

BEGIN;

    SELECT bucket, player_id, category, role, count FROM structs.planet_activity_player_daily WHERE FALSE;

    DO $$
    DECLARE
        v_day  TIMESTAMPTZ := (date_trunc('day', now() AT TIME ZONE 'UTC' - INTERVAL '2 days')) AT TIME ZONE 'UTC'; -- a UTC-midnight bucket boundary
        v_raw  BIGINT;
        v_cagg BIGINT;
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM timescaledb_information.continuous_aggregates
             WHERE view_schema = 'structs' AND view_name = 'planet_activity_player_daily'
        ) THEN
            RAISE EXCEPTION 'structs.planet_activity_player_daily is not a continuous aggregate';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM timescaledb_information.jobs j
             WHERE j.hypertable_schema = 'structs' AND j.hypertable_name = 'planet_activity_player_daily'
               AND j.proc_name = 'policy_refresh_continuous_aggregate'
        ) THEN
            RAISE EXCEPTION 'no refresh policy on structs.planet_activity_player_daily';
        END IF;

        SELECT count(*) INTO v_raw
          FROM structs.planet_activity_player
         WHERE time >= v_day AND time < v_day + INTERVAL '1 day';

        SELECT COALESCE(sum(count), 0) INTO v_cagg
          FROM structs.planet_activity_player_daily
         WHERE bucket = v_day;

        IF v_raw <> v_cagg THEN
            RAISE EXCEPTION 'planet_activity_player_daily disagrees with raw for %: raw % vs cagg %', v_day, v_raw, v_cagg;
        END IF;
    END
    $$;

ROLLBACK;
