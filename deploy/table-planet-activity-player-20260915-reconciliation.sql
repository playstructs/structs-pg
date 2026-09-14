-- Deploy structs-pg:table-planet-activity-player-20260915-reconciliation to pg
--
-- Nightly check that structs.planet_activity_player matches what
-- structs.planet_activity_players() says for recent rows.
--
-- states:
--   missing  the specification yields (player, role) for an activity row but
--            the side table has no such row: the trigger did not fire (direct
--            COPY / bulk load, or trigger disabled) or ownership was unknown
--            at insert time and is known now.
--   extra    the side table has a row the specification no longer yields:
--            the parent row was deleted, or ownership changed since the event.
--            Ownership changes are expected drift, not errors; the side table
--            deliberately keeps ownership as of the event.
--   orphan   side row whose parent planet_activity row no longer exists.
--
-- The window defaults to 2 days so the check stays cheap and ownership churn
-- does not accumulate into noise. Repair for genuine gaps is
-- structs.planet_activity_player_backfill(from, to).

BEGIN;

    CREATE TABLE structs.planet_activity_player_drift (
        checked_at TIMESTAMPTZ NOT NULL,
        time       TIMESTAMPTZ NOT NULL,
        planet_id  CHARACTER VARYING NOT NULL,
        seq        INTEGER NOT NULL,
        player_id  CHARACTER VARYING NOT NULL,
        role       TEXT NOT NULL,
        state      TEXT NOT NULL CHECK (state IN ('missing', 'extra', 'orphan')),
        category   structs.grass_category,
        PRIMARY KEY (checked_at, time, planet_id, seq, player_id, role, state)
    );

    COMMENT ON TABLE structs.planet_activity_player_drift IS
        'Differences between structs.planet_activity_player and structs.planet_activity_players() over the reconciler window, one batch per checked_at. Written by structs.planet_activity_player_reconcile().';

    CREATE OR REPLACE FUNCTION structs.planet_activity_player_reconcile(
        p_log   BOOLEAN  DEFAULT TRUE,
        p_since INTERVAL DEFAULT INTERVAL '2 days'
    )
    RETURNS TABLE (
        "time"    TIMESTAMPTZ,
        planet_id CHARACTER VARYING,
        seq       INTEGER,
        player_id CHARACTER VARYING,
        role      TEXT,
        state     TEXT,
        category  structs.grass_category
    )
    LANGUAGE plpgsql
    SET max_parallel_workers_per_gather = 0
    AS
    $BODY$
    #variable_conflict use_column
    DECLARE
        v_checked_at TIMESTAMPTZ := clock_timestamp();
        v_from       TIMESTAMPTZ := clock_timestamp() - p_since;
    BEGIN
        DROP TABLE IF EXISTS pg_temp.planet_activity_player_reconcile_tmp;

        CREATE TEMP TABLE planet_activity_player_reconcile_tmp ON COMMIT DROP AS
        WITH expected AS (
            SELECT pa.time, pa.planet_id, pa.seq, a.player_id, a.role, pa.category
              FROM structs.planet_activity pa
              CROSS JOIN LATERAL structs.planet_activity_players(pa.category, pa.planet_id, pa.detail) a
             WHERE pa.time >= v_from
        ),
        actual AS (
            SELECT pap.time, pap.planet_id, pap.seq, pap.player_id, pap.role, pap.category
              FROM structs.planet_activity_player pap
             WHERE pap.time >= v_from
        )
        SELECT e.time, e.planet_id, e.seq, e.player_id, e.role, 'missing'::text AS state, e.category
          FROM expected e
         WHERE NOT EXISTS (
                   SELECT 1 FROM actual a
                    WHERE a.time = e.time AND a.planet_id = e.planet_id AND a.seq = e.seq
                      AND a.player_id = e.player_id AND a.role = e.role)
        UNION ALL
        SELECT a.time, a.planet_id, a.seq, a.player_id, a.role,
               CASE WHEN EXISTS (SELECT 1 FROM structs.planet_activity pa
                                  WHERE pa.time = a.time AND pa.planet_id = a.planet_id AND pa.seq = a.seq)
                    THEN 'extra' ELSE 'orphan' END,
               a.category
          FROM actual a
         WHERE NOT EXISTS (
                   SELECT 1 FROM expected e
                    WHERE e.time = a.time AND e.planet_id = a.planet_id AND e.seq = a.seq
                      AND e.player_id = a.player_id AND e.role = a.role);

        IF p_log THEN
            INSERT INTO structs.planet_activity_player_drift
                (checked_at, time, planet_id, seq, player_id, role, state, category)
            SELECT v_checked_at, t.time, t.planet_id, t.seq, t.player_id, t.role, t.state, t.category
              FROM planet_activity_player_reconcile_tmp t;

            DELETE FROM structs.planet_activity_player_drift d
             WHERE d.checked_at < v_checked_at - INTERVAL '90 days';
        END IF;

        RETURN QUERY
            SELECT t.time, t.planet_id, t.seq, t.player_id, t.role, t.state, t.category
              FROM planet_activity_player_reconcile_tmp t
             ORDER BY t.time, t.planet_id, t.seq, t.player_id, t.role;
    END
    $BODY$;

    COMMENT ON FUNCTION structs.planet_activity_player_reconcile(BOOLEAN, INTERVAL) IS
        'Compare planet_activity_player with planet_activity_players() over the last p_since. Returns missing/extra/orphan rows; logs to planet_activity_player_drift when p_log. Repair: planet_activity_player_backfill(from, to).';

    GRANT EXECUTE
        ON FUNCTION structs.planet_activity_player_reconcile(BOOLEAN, INTERVAL)
        TO structs_indexer;

    GRANT SELECT, UPDATE, DELETE
        ON structs.planet_activity_player_drift
        TO structs_indexer;

    SELECT cron.schedule(
        'planet_activity_player_reconciler',
        '33 3 * * *',
        'SELECT count(*) FROM structs.planet_activity_player_reconcile(TRUE);'
    );

COMMIT;
