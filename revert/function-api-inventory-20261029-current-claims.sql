-- Revert structs-pg:function-api-inventory-20261029-current-claims from pg
BEGIN;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM structs.api_refresh_state WHERE inventory_authority='current-claims-v1')
       OR EXISTS (SELECT 1 FROM structs.api_inventory WHERE balance IS NULL) THEN
        RAISE EXCEPTION 'current claims are active; restore a verified pre-switch checkpoint instead of reviving ledger-derived claims';
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

CREATE OR REPLACE VIEW view.guild_inventory AS
    SELECT p.guild_id,
           structs.UNIT_LEGACY_FORMAT(sum(i.balance), i.denom) AS balance,
           CASE i.denom WHEN 'ore' THEN 'ore' ELSE substring(i.denom, 2, length(i.denom) - 1) END AS denom
      FROM structs.api_inventory i
      JOIN structs.player p ON p.id = i.owner_id
     WHERE i.owner_type = 'player'
     GROUP BY p.guild_id, i.denom;


DROP FUNCTION structs.api_inventory_expected(BOOLEAN);
DROP FUNCTION structs.api_inventory_address_expected(VARCHAR[],BOOLEAN);
DROP FUNCTION structs.api_inventory_current_claims(VARCHAR[]);
DROP TRIGGER API_INVENTORY_CLAIM_NOTIFY ON structs.api_inventory;
DROP FUNCTION structs.API_INVENTORY_CLAIM_NOTIFY();
DROP INDEX structs.infusion_address_claim_idx;
REVOKE SELECT ON structs.infusion FROM structs_indexer;
ALTER TABLE structs.api_inventory DROP CONSTRAINT api_inventory_unknown_claim;
ALTER TABLE structs.api_inventory ALTER COLUMN balance SET NOT NULL;
ALTER TABLE structs.api_refresh_state DROP COLUMN inventory_authority;
COMMENT ON COLUMN structs.api_inventory.balance IS NULL;
COMMENT ON COLUMN structs.api_inventory_drift.ledger_balance IS
    'Chain precision. Signed sum of ledger.amount_p at check time; NULL when the ledger has no rows for the key.';
COMMIT;
