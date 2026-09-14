-- Revert structs-pg:table-planet-activity-player-20260915-reconciliation from pg

BEGIN;

    SELECT cron.unschedule('planet_activity_player_reconciler');

    DROP FUNCTION IF EXISTS structs.planet_activity_player_reconcile(BOOLEAN, INTERVAL);

    DROP TABLE IF EXISTS structs.planet_activity_player_drift;

COMMIT;
