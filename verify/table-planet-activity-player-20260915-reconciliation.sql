-- Verify structs-pg:table-planet-activity-player-20260915-reconciliation on pg
--
-- Structure plus a bounded functional run: right after the deploy backfill the
-- reconciler over the last hour must report no 'missing' rows. 'extra' rows
-- can legitimately exist (ownership changed since the event) and are not
-- asserted on.

BEGIN;

    SELECT checked_at, time, planet_id, seq, player_id, role, state, category
      FROM structs.planet_activity_player_drift WHERE FALSE;

    DO $$
    DECLARE
        v_missing BIGINT;
    BEGIN
        IF to_regprocedure('structs.planet_activity_player_reconcile(boolean, interval)') IS NULL THEN
            RAISE EXCEPTION 'expected structs.planet_activity_player_reconcile(boolean, interval)';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'planet_activity_player_reconciler') THEN
            RAISE EXCEPTION 'planet_activity_player_reconciler cron job is not scheduled';
        END IF;

        SELECT count(*) INTO v_missing
          FROM structs.planet_activity_player_reconcile(FALSE, INTERVAL '1 hour')
         WHERE state = 'missing';

        IF v_missing <> 0 THEN
            RAISE EXCEPTION 'reconciler reports % missing attribution rows in the last hour', v_missing;
        END IF;
    END
    $$;

ROLLBACK;
