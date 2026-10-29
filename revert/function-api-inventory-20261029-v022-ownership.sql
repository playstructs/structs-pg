-- Revert structs-pg:function-api-inventory-20261029-v022-ownership from pg
-- Stop the v0.22 writer before reverting its maintenance contract.
BEGIN;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM structs.vault) THEN
        RAISE EXCEPTION 'cannot restore legacy ownership maintenance after vault state exists; restore a coordinated pre-upgrade snapshot';
    END IF;
END $$;

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
        SELECT rs.source_height INTO v_source_height
          FROM structs.api_refresh_state rs
         WHERE rs.model = 'inventory';

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
            SELECT 'player'::structs.object_type,
                   pa.player_id,
                   a.denom,
                   SUM(a.balance)
              FROM addr a
              JOIN structs.player_address pa ON pa.address = a.address
             GROUP BY pa.player_id, a.denom
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
    $$SELECT * FROM structs.api_work_refresh_full((SELECT source_height FROM structs.api_refresh_state WHERE model = 'work'), now(), TRUE)$$
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
        SELECT rs.source_height INTO v_source_height
          FROM structs.api_refresh_state rs
         WHERE rs.model = 'work';

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


DROP FUNCTION structs.api_work_refresh_scheduled();
DROP FUNCTION structs.api_projection_boundary();
REVOKE INSERT ON structs.api_inventory_drift, structs.api_work_drift FROM structs_indexer;
CREATE OR REPLACE VIEW view.guild_inventory AS
    SELECT player_address.guild_id, sum(address_inventory.balance) AS balance, address_inventory.denom
      FROM structs.player_address, view.address_inventory
     WHERE player_address.address = address_inventory.address
     GROUP BY player_address.guild_id, address_inventory.denom;
COMMIT;
