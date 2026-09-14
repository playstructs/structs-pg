-- Verify structs-pg:function-planet-activity-player-20260915-backfill on pg
--
-- The function exists and the last 7 days of planet_activity are fully
-- attributed: every row for which the specification yields players has at
-- least one side row. (Whole-history exactness is the reconciler's job.)

BEGIN;

    DO $$
    DECLARE
        v_missing BIGINT;
    BEGIN
        IF to_regprocedure('structs.planet_activity_player_backfill(timestamptz, timestamptz)') IS NULL THEN
            RAISE EXCEPTION 'expected structs.planet_activity_player_backfill(timestamptz, timestamptz)';
        END IF;

        SELECT count(*) INTO v_missing
          FROM structs.planet_activity pa
         WHERE pa.time >= now() - INTERVAL '7 days'
           AND EXISTS (SELECT 1 FROM structs.planet_activity_players(pa.category, pa.planet_id, pa.detail))
           AND NOT EXISTS (
               SELECT 1 FROM structs.planet_activity_player pap
                WHERE pap.time = pa.time AND pap.planet_id = pa.planet_id AND pap.seq = pa.seq
           );

        IF v_missing <> 0 THEN
            RAISE EXCEPTION 'backfill incomplete: % attributable planet_activity rows in the last 7 days have no planet_activity_player row', v_missing;
        END IF;
    END
    $$;

ROLLBACK;
