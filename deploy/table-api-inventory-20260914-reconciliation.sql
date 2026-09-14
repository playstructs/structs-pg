-- Deploy structs-pg:table-api-inventory-20260914-reconciliation to pg
--
-- Out-of-band checker for structs.api_inventory. Once sync-state maintains
-- inventory as a running balance (see docs/sync-state-ledger-identity-
-- handoff.md) the only place a full structs.ledger aggregate belongs is a
-- scheduled reconciliation, never a request or per-block path.
--
-- structs.api_inventory_reconcile() recomputes every (owner_type, owner_id,
-- denom) balance from the ledger in one snapshot, compares it with
-- api_inventory, returns the mismatches, and (by default) logs them to
-- structs.api_inventory_drift. It never writes api_inventory: that table is
-- indexer-owned and sync-state decides how to repair drift.
--
-- Zero balances are treated as equivalent to a missing row on either side so
-- sync-state may omit or keep zero rows without producing false drift.
--
-- Parallel workers are disabled inside the function: the container runs with
-- a 64 MB /dev/shm and large parallel hash aggregates fail with "could not
-- resize shared memory segment". Remove the SET once shm_size is raised.

BEGIN;

    CREATE TABLE structs.api_inventory_drift (
        checked_at     TIMESTAMPTZ NOT NULL,
        owner_type     structs.object_type NOT NULL,
        owner_id       CHARACTER VARYING NOT NULL,
        denom          TEXT NOT NULL,
        api_balance    NUMERIC,
        ledger_balance NUMERIC,
        source_height  BIGINT,
        PRIMARY KEY (checked_at, owner_type, owner_id, denom)
    );

    COMMENT ON TABLE structs.api_inventory_drift IS
        'Mismatches between structs.api_inventory and a full structs.ledger aggregate, one batch per checked_at. Written by structs.api_inventory_reconcile(); sync-state consumes and repairs.';
    COMMENT ON COLUMN structs.api_inventory_drift.api_balance IS
        'Chain precision. Balance held in api_inventory at check time; NULL when the row was missing.';
    COMMENT ON COLUMN structs.api_inventory_drift.ledger_balance IS
        'Chain precision. Signed sum of ledger.amount_p at check time; NULL when the ledger has no rows for the key.';
    COMMENT ON COLUMN structs.api_inventory_drift.source_height IS
        'structs.api_refresh_state.source_height for model ''inventory'' at check time.';

    CREATE INDEX api_inventory_drift_owner_idx
        ON structs.api_inventory_drift (owner_type, owner_id, denom, checked_at DESC);

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
        'api_inventory_reconciler',
        '17 3 * * *',
        'SELECT count(*) FROM structs.api_inventory_reconcile(TRUE);'
    );

COMMIT;
