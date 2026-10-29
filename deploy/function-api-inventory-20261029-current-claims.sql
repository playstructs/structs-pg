-- Deploy structs-pg:function-api-inventory-20261029-current-claims to pg
BEGIN;

-- Predeployment leaves existing writers and scheduled comparisons on their
-- existing contract. The new writer changes this marker with its full rebuild.
ALTER TABLE structs.api_refresh_state ADD COLUMN inventory_authority TEXT NOT NULL DEFAULT 'ledger'
    CHECK (inventory_authority IN ('ledger', 'current-claims-v1'));
ALTER TABLE structs.api_inventory ALTER COLUMN balance DROP NOT NULL;
ALTER TABLE structs.api_inventory ADD CONSTRAINT api_inventory_unknown_claim
    CHECK (balance IS NOT NULL OR denom IN ('ualpha.infused', 'ualpha.defusing'));
COMMENT ON COLUMN structs.api_inventory.balance IS
    'Exact chain units. NULL synthetic claims are unknown, never zero; real bank denominations remain non-null.';
CREATE INDEX infusion_address_claim_idx ON structs.infusion(address);
GRANT SELECT ON structs.infusion TO structs_indexer;

-- Shared current-claim arithmetic. Live refresh supplies a bounded set from
-- indexed current state; only rebuild/reconciliation discovers ledger history.
CREATE FUNCTION structs.api_inventory_current_claims(p_addresses VARCHAR[])
RETURNS TABLE(address VARCHAR,denom TEXT,balance NUMERIC)
LANGUAGE sql STABLE AS $BODY$
    WITH chain AS (
        SELECT min(chain_id) AS id FROM sync_state.sync_cursor HAVING count(*)=1
    ), claims AS (
        SELECT a.address,n.bonded,n.unbonding,
               COALESCE(g.fuel,0) AS generator_fuel,COALESCE(g.unknown,FALSE) AS generator_unknown
        FROM (SELECT DISTINCT unnest(p_addresses) AS address) a
        LEFT JOIN chain c ON TRUE
        LEFT JOIN sync_state.native_staking_claim n ON n.chain_id=c.id AND n.address=a.address
        LEFT JOIN LATERAL (
            SELECT SUM(i.fuel_p) AS fuel,bool_or(i.fuel_p IS NULL) AS unknown
            FROM structs.infusion i WHERE i.address=a.address AND i.destination_type='struct'
            -- Disabled generators retain fuel. Only actual deletion removes it.
        ) g ON TRUE
    )
    SELECT c.address,'ualpha.infused',
           CASE WHEN NOT c.generator_unknown THEN c.bonded+c.generator_fuel END FROM claims c
    UNION ALL
    SELECT c.address,'ualpha.defusing',c.unbonding FROM claims c;
$BODY$;

CREATE FUNCTION structs.api_inventory_address_expected(
    p_addresses VARCHAR[] DEFAULT NULL, p_current_claims BOOLEAN DEFAULT NULL
) RETURNS TABLE(address VARCHAR, denom TEXT, balance NUMERIC)
LANGUAGE sql STABLE AS $BODY$
    WITH mode AS (
        SELECT COALESCE(p_current_claims, EXISTS (
            SELECT 1 FROM structs.api_refresh_state
            WHERE model='inventory' AND inventory_authority='current-claims-v1'
        )) AS claims
    ), chain AS (
        SELECT min(chain_id) AS id FROM sync_state.sync_cursor HAVING count(*)=1
    ), bank AS (
        SELECT l.address, l.denom,
               SUM(CASE l.direction WHEN 'credit' THEN l.amount_p ELSE -l.amount_p END) AS balance
        FROM structs.ledger l, mode m
        WHERE l.address IS NOT NULL AND l.denom IS NOT NULL
          AND (p_addresses IS NULL OR l.address=ANY(p_addresses))
          AND (NOT m.claims OR l.denom NOT IN ('ualpha.infused','ualpha.defusing'))
        GROUP BY l.address,l.denom
    ), candidates AS (
        SELECT ao.address FROM structs.asset_owner ao, mode m
        WHERE m.claims AND (p_addresses IS NULL OR ao.address=ANY(p_addresses))
        UNION
        SELECT s.address FROM sync_state.native_staking_snapshot s JOIN chain c ON c.id=s.chain_id, mode m
        WHERE m.claims AND (p_addresses IS NULL OR s.address=ANY(p_addresses))
        UNION
        SELECT i.address FROM structs.infusion i, mode m
        WHERE m.claims AND (p_addresses IS NULL OR i.address=ANY(p_addresses))
        UNION
        SELECT l.address FROM structs.ledger l, mode m
        WHERE m.claims AND l.denom IN ('ualpha.infused','ualpha.defusing')
          AND l.address IS NOT NULL AND (p_addresses IS NULL OR l.address=ANY(p_addresses))
    )
    SELECT b.address,b.denom::TEXT,b.balance FROM bank b
    UNION ALL
    SELECT * FROM structs.api_inventory_current_claims(ARRAY(SELECT c.address FROM candidates c));
$BODY$;

CREATE FUNCTION structs.api_inventory_expected(p_current_claims BOOLEAN DEFAULT NULL)
RETURNS TABLE(owner_type structs.object_type, owner_id VARCHAR, denom TEXT, balance NUMERIC)
LANGUAGE sql STABLE AS $BODY$
    WITH addr AS MATERIALIZED (
        SELECT * FROM structs.api_inventory_address_expected(NULL,p_current_claims)
    )
    SELECT 'address'::structs.object_type,a.address,a.denom,a.balance FROM addr a
    UNION ALL
    SELECT ao.owner_type,ao.owner_id,a.denom,
           CASE WHEN count(*)=count(a.balance) THEN SUM(a.balance) END
    FROM addr a JOIN structs.asset_owner ao ON ao.address=a.address
    GROUP BY ao.owner_type,ao.owner_id,a.denom;
$BODY$;
GRANT EXECUTE ON FUNCTION structs.api_inventory_current_claims(VARCHAR[]),
    structs.api_inventory_address_expected(VARCHAR[],BOOLEAN),
    structs.api_inventory_expected(BOOLEAN) TO structs_indexer;

-- The output name ledger_balance is retained for callers. It is the current
-- expected claim for synthetic categories once the writer activates them.
CREATE OR REPLACE FUNCTION structs.api_inventory_reconcile(p_log BOOLEAN DEFAULT TRUE)
RETURNS TABLE(owner_type structs.object_type,owner_id VARCHAR,denom TEXT,api_balance NUMERIC,ledger_balance NUMERIC)
LANGUAGE plpgsql SET max_parallel_workers_per_gather=0 AS $BODY$
#variable_conflict use_column
DECLARE v_checked_at TIMESTAMPTZ; v_source_height BIGINT; v_current_claims BOOLEAN;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('structs.api_work_refresh'));
    SELECT b.source_height INTO v_source_height FROM structs.api_projection_boundary() b;
    IF NOT FOUND THEN RETURN; END IF;
    SELECT inventory_authority='current-claims-v1' INTO v_current_claims
    FROM structs.api_refresh_state WHERE model='inventory';
    v_checked_at := clock_timestamp();
    DROP TABLE IF EXISTS pg_temp.api_inventory_reconcile_tmp;
    CREATE TEMP TABLE api_inventory_reconcile_tmp ON COMMIT DROP AS
    SELECT COALESCE(e.owner_type,i.owner_type) AS owner_type,
           COALESCE(e.owner_id,i.owner_id) AS owner_id,COALESCE(e.denom,i.denom) AS denom,
           i.balance AS api_balance,e.balance AS ledger_balance
    FROM structs.api_inventory_expected(v_current_claims) e
    FULL JOIN structs.api_inventory i USING(owner_type,owner_id,denom)
    WHERE CASE WHEN v_current_claims AND COALESCE(e.denom,i.denom) IN ('ualpha.infused','ualpha.defusing')
        THEN e.owner_id IS NULL OR i.owner_id IS NULL OR i.balance IS DISTINCT FROM e.balance
        ELSE COALESCE(i.balance,0) <> COALESCE(e.balance,0) END;
    IF p_log THEN
        INSERT INTO structs.api_inventory_drift(checked_at,owner_type,owner_id,denom,api_balance,ledger_balance,source_height)
        SELECT v_checked_at,t.owner_type,t.owner_id,t.denom,t.api_balance,t.ledger_balance,v_source_height
        FROM api_inventory_reconcile_tmp t;
        DELETE FROM structs.api_inventory_drift d WHERE d.checked_at<v_checked_at-INTERVAL '90 days';
    END IF;
    RETURN QUERY SELECT t.owner_type,t.owner_id,t.denom,t.api_balance,t.ledger_balance
        FROM api_inventory_reconcile_tmp t ORDER BY t.owner_type,t.owner_id,t.denom;
END
$BODY$;
COMMENT ON COLUMN structs.api_inventory_drift.ledger_balance IS
    'Expected bank ledger balance or current synthetic claim; NULL means unknown or absent. Repairs re-read current authority, never this historical value.';
COMMENT ON FUNCTION structs.api_inventory_reconcile(BOOLEAN) IS
    'Compare inventory with its activated bank/current-claim authority; unknown and zero claims are distinct. Read-only except optional drift logging.';

CREATE OR REPLACE VIEW view.guild_inventory AS
    SELECT p.guild_id,
           structs.UNIT_LEGACY_FORMAT(CASE WHEN count(*)=count(i.balance) THEN sum(i.balance) END,i.denom) AS balance,
           CASE i.denom WHEN 'ore' THEN 'ore' ELSE substring(i.denom,2,length(i.denom)-1) END AS denom
    FROM structs.api_inventory i JOIN structs.player p ON p.id=i.owner_id
    WHERE i.owner_type='player' GROUP BY p.guild_id,i.denom;

-- Cache publication and ownership movement can change value without a bank
-- receipt. Publish an invalidation on the existing owner consensus subject,
-- after the projection write; transaction rollback also rolls back the hint.
CREATE FUNCTION structs.API_INVENTORY_CLAIM_NOTIFY() RETURNS trigger AS $BODY$
DECLARE r structs.api_inventory%ROWTYPE;
BEGIN
    IF TG_OP='DELETE' THEN r := OLD; ELSE r := NEW; END IF;
    IF r.owner_type IN ('player','guild') AND r.denom IN ('ualpha.infused','ualpha.defusing') THEN
        IF TG_OP='UPDATE' AND OLD.balance IS NOT DISTINCT FROM NEW.balance THEN RETURN NEW; END IF;
        PERFORM pg_notify('grass',jsonb_build_object(
            'subject','structs.grid.' || r.owner_type::TEXT || '.' || r.owner_id,
            'category',r.owner_type::TEXT || '_consensus',
            'notification_owner_type',r.owner_type,'notification_owner_id',r.owner_id,
            'invalidates','inventory','denom',r.denom)::TEXT);
    END IF;
    IF TG_OP='DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END
$BODY$ LANGUAGE plpgsql;
CREATE TRIGGER API_INVENTORY_CLAIM_NOTIFY AFTER INSERT OR UPDATE OR DELETE ON structs.api_inventory
    FOR EACH ROW EXECUTE FUNCTION structs.API_INVENTORY_CLAIM_NOTIFY();
COMMIT;
