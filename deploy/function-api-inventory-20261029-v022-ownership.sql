-- Deploy structs-pg:function-api-inventory-20261029-v022-ownership to pg
-- Current ownership is shared by incremental, full and repair projections.
BEGIN;

-- Read only after acquiring the shared transaction maintenance lock. An
-- incomplete/deferred projection has no boundary and is never stamped ready.
CREATE FUNCTION structs.api_projection_boundary()
RETURNS TABLE(source_height BIGINT, source_time TIMESTAMPTZ)
LANGUAGE sql AS $BODY$
    SELECT rs.source_height, rs.source_time
      FROM structs.api_refresh_state rs
      JOIN sync_state.sync_cursor c ON c.last_height = rs.source_height
       AND c.last_block_time IS NOT DISTINCT FROM rs.source_time
      JOIN structs.current_block b ON b.chain = c.chain_id AND b.height = c.last_height
     WHERE rs.model = 'inventory'
       AND (SELECT count(*) FROM sync_state.sync_cursor) = 1
       AND (SELECT count(*) FROM structs.current_block) = 1;
$BODY$;

CREATE FUNCTION structs.api_work_refresh_scheduled()
RETURNS TABLE(inserted BIGINT, updated BIGINT, deleted BIGINT)
LANGUAGE plpgsql AS $BODY$
DECLARE
    v_height BIGINT;
    v_time TIMESTAMPTZ;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('structs.api_work_refresh'));
    SELECT b.source_height, b.source_time INTO v_height, v_time
      FROM structs.api_projection_boundary() b;
    IF NOT FOUND THEN
        RETURN;
    END IF;
    -- Arguments are obtained after waiting, never from the cron statement's
    -- pre-lock snapshot. The existing work refresh lock is reentrant.
    RETURN QUERY SELECT * FROM structs.api_work_refresh_full(v_height, v_time, TRUE);
END
$BODY$;
GRANT EXECUTE ON FUNCTION structs.api_projection_boundary(), structs.api_work_refresh_scheduled() TO structs_indexer;
GRANT INSERT ON structs.api_inventory_drift, structs.api_work_drift TO structs_indexer;

    CREATE OR REPLACE FUNCTION structs.api_inventory_reconcile(p_log BOOLEAN DEFAULT TRUE)
    RETURNS TABLE (
        owner_type     structs.object_type,
        owner_id       CHARACTER VARYING,
        denom          TEXT,
        api_balance    NUMERIC,
        ledger_balance NUMERIC
    )
    LANGUAGE plpgsql
    SET max_parallel_workers_per_gather = 0
    AS
    $BODY$
    #variable_conflict use_column
    DECLARE
        v_checked_at    TIMESTAMPTZ := clock_timestamp();
        v_source_height BIGINT;
    BEGIN
        PERFORM pg_advisory_xact_lock(hashtext('structs.api_work_refresh'));
        SELECT b.source_height INTO v_source_height
          FROM structs.api_projection_boundary() b;
        IF NOT FOUND THEN
            RETURN; -- No complete committed projection boundary to compare.
        END IF;
        v_checked_at := clock_timestamp();

        DROP TABLE IF EXISTS pg_temp.api_inventory_reconcile_tmp;

        CREATE TEMP TABLE api_inventory_reconcile_tmp ON COMMIT DROP AS
        WITH addr AS (
            SELECT l.address,
                   l.denom,
                   SUM(CASE l.direction
                           WHEN 'credit' THEN l.amount_p
                           ELSE -l.amount_p
                       END) AS balance
              FROM structs.ledger l
             WHERE l.address IS NOT NULL
               AND l.denom IS NOT NULL
             GROUP BY l.address, l.denom
        ), expected AS (
            SELECT 'address'::structs.object_type AS owner_type,
                   a.address AS owner_id,
                   a.denom,
                   a.balance
              FROM addr a
            UNION ALL
            SELECT ao.owner_type,
                   ao.owner_id,
                   a.denom,
                   SUM(a.balance)
              FROM addr a
              JOIN structs.asset_owner ao ON ao.address = a.address
             GROUP BY ao.owner_type, ao.owner_id, a.denom
        )
        SELECT COALESCE(e.owner_type, i.owner_type) AS owner_type,
               COALESCE(e.owner_id,   i.owner_id)   AS owner_id,
               COALESCE(e.denom,      i.denom)      AS denom,
               i.balance                            AS api_balance,
               e.balance                            AS ledger_balance
          FROM expected e
          FULL OUTER JOIN structs.api_inventory i
            ON i.owner_type = e.owner_type
           AND i.owner_id   = e.owner_id
           AND i.denom      = e.denom
         WHERE COALESCE(i.balance, 0) <> COALESCE(e.balance, 0);

        IF p_log THEN
            INSERT INTO structs.api_inventory_drift
                (checked_at, owner_type, owner_id, denom,
                 api_balance, ledger_balance, source_height)
            SELECT v_checked_at, t.owner_type, t.owner_id, t.denom,
                   t.api_balance, t.ledger_balance, v_source_height
              FROM api_inventory_reconcile_tmp t;

            DELETE FROM structs.api_inventory_drift d
             WHERE d.checked_at < v_checked_at - INTERVAL '90 days';
        END IF;

        RETURN QUERY
            SELECT t.owner_type, t.owner_id, t.denom, t.api_balance, t.ledger_balance
              FROM api_inventory_reconcile_tmp t
             ORDER BY t.owner_type, t.owner_id, t.denom;
    END
    $BODY$;

    COMMENT ON FUNCTION structs.api_inventory_reconcile(BOOLEAN) IS
        'Full ledger vs api_inventory comparison. Returns mismatches; logs them to api_inventory_drift when p_log. Read-only with respect to api_inventory.';

SELECT cron.schedule(
    'api-work-refresh-full-hourly', '7 * * * *',
    'SELECT * FROM structs.api_work_refresh_scheduled();'
);

    CREATE OR REPLACE FUNCTION structs.api_work_reconcile(p_log BOOLEAN DEFAULT TRUE)
    RETURNS TABLE (
        category  TEXT,
        object_id CHARACTER VARYING,
        target_id CHARACTER VARYING,
        state     TEXT,
        api_row   JSONB,
        live_row  JSONB
    )
    LANGUAGE plpgsql
    SET max_parallel_workers_per_gather = 0
    AS
    $BODY$
    #variable_conflict use_column
    DECLARE
        v_checked_at    TIMESTAMPTZ := clock_timestamp();
        v_source_height BIGINT;
    BEGIN
        PERFORM pg_advisory_xact_lock(hashtext('structs.api_work_refresh'));
        SELECT b.source_height INTO v_source_height
          FROM structs.api_projection_boundary() b;
        IF NOT FOUND THEN
            RETURN;
        END IF;
        v_checked_at := clock_timestamp();

        DROP TABLE IF EXISTS pg_temp.api_work_reconcile_tmp;

        CREATE TEMP TABLE api_work_reconcile_tmp ON COMMIT DROP AS
        SELECT COALESCE(l.category,  a.category)  AS category,
               COALESCE(l.object_id, a.object_id) AS object_id,
               COALESCE(l.target_id, a.target_id) AS target_id,
               CASE
                   WHEN a.category IS NULL THEN 'missing'
                   WHEN l.category IS NULL THEN 'extra'
                   ELSE 'stale'
               END AS state,
               CASE WHEN a.category IS NULL THEN NULL ELSE jsonb_build_object(
                   'player_id', a.player_id, 'block_start', a.block_start,
                   'difficulty_target', a.difficulty_target, 'location_type', a.location_type,
                   'location_id', a.location_id, 'planet_id', a.planet_id,
                   'source_height', a.source_height) END AS api_row,
               CASE WHEN l.category IS NULL THEN NULL ELSE jsonb_build_object(
                   'player_id', l.player_id, 'block_start', l.block_start,
                   'difficulty_target', l.difficulty_target, 'location_type', l.location_type,
                   'location_id', l.location_id, 'planet_id', l.planet_id) END AS live_row
          FROM view.work_live l
          FULL OUTER JOIN structs.api_work a
            ON a.category  = l.category
           AND a.object_id = l.object_id
           AND a.target_id = l.target_id
         WHERE a.category IS NULL
            OR l.category IS NULL
            OR (a.player_id, a.block_start, a.difficulty_target,
                a.location_type, a.location_id, a.planet_id)
               IS DISTINCT FROM
               (l.player_id, l.block_start, l.difficulty_target,
                l.location_type, l.location_id, l.planet_id);

        IF p_log THEN
            INSERT INTO structs.api_work_drift
                (checked_at, category, object_id, target_id, state, api_row, live_row, source_height)
            SELECT v_checked_at, t.category, t.object_id, t.target_id,
                   t.state, t.api_row, t.live_row, v_source_height
              FROM api_work_reconcile_tmp t;

            DELETE FROM structs.api_work_drift d
             WHERE d.checked_at < v_checked_at - INTERVAL '90 days';
        END IF;

        RETURN QUERY
            SELECT t.category, t.object_id, t.target_id, t.state, t.api_row, t.live_row
              FROM api_work_reconcile_tmp t
             ORDER BY t.category, t.object_id, t.target_id;
    END
    $BODY$;

    COMMENT ON FUNCTION structs.api_work_reconcile(BOOLEAN) IS
        'Compare structs.api_work with view.work_live. Returns missing/extra/stale keys; logs them to api_work_drift when p_log. Read-only with respect to api_work; the next api_work_refresh() repairs any drift.';


-- This legacy view is member wealth grouped by current guild, not the guild
-- treasury. Keep that meaning while including player vaults exactly once.
CREATE OR REPLACE VIEW view.guild_inventory AS
    SELECT p.guild_id,
           structs.UNIT_LEGACY_FORMAT(sum(i.balance), i.denom) AS balance,
           CASE i.denom WHEN 'ore' THEN 'ore' ELSE substring(i.denom, 2, length(i.denom) - 1) END AS denom
      FROM structs.api_inventory i
      JOIN structs.player p ON p.id = i.owner_id
     WHERE i.owner_type = 'player'
     GROUP BY p.guild_id, i.denom;

COMMIT;
