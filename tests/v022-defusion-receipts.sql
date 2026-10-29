-- Run against the Sqitch-deployed disposable database; every fixture rolls back.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE structs_indexer;
DO $$
DECLARE bad TEXT; privilege TEXT;
BEGIN
    IF (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) THEN
        RAISE EXCEPTION 'requires a non-superuser indexer';
    END IF;
    -- Legacy writers can still insert unidentified receipts; no fake source key.
    INSERT INTO structs.defusion(validator_address,delegator_address,defusion_type,amount_p,denom,completed_at)
    SELECT 'receipt-sql-validator','receipt-sql-address','u',7,'ualpha','2000-01-01' FROM generate_series(1,2);
    CALL structs.CLEAN_DEFUSION();
    IF (SELECT count(*) FROM structs.defusion_current WHERE delegator_address='receipt-sql-address'
        AND pending_state='unidentified' AND block_height IS NULL) <> 2 THEN
        RAISE EXCEPTION 'legacy receipt lost or assigned invented identity';
    END IF;
    INSERT INTO structs.defusion(validator_address,delegator_address,defusion_type,amount_p,denom,completed_at,
        chain_id,block_height,tx_index,event_index)
    VALUES('receipt-sql-validator','receipt-sql-address','u',18446744073709551616,'ualpha','2000-01-01','receipt-sql',100,0,0);
    FOREACH bad IN ARRAY ARRAY['-1','1.1','NaN','Infinity','-Infinity'] LOOP
        BEGIN
            UPDATE structs.defusion SET amount_p=bad::numeric WHERE chain_id='receipt-sql';
            RAISE EXCEPTION 'invalid source amount accepted: %',bad;
        EXCEPTION WHEN check_violation THEN NULL;
        END;
    END LOOP;
    BEGIN
        UPDATE structs.defusion SET event_index=NULL WHERE chain_id='receipt-sql';
        RAISE EXCEPTION 'partial source key accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        UPDATE structs.defusion SET reconciled_height=99,retired_height=99 WHERE chain_id='receipt-sql';
        RAISE EXCEPTION 'snapshot predating receipt accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    UPDATE structs.defusion SET reconciled_height=101,retired_height=101 WHERE chain_id='receipt-sql';
    INSERT INTO structs.defusion(validator_address,delegator_address,defusion_type,amount_p,denom,completed_at,
        chain_id,block_height,tx_index,event_index)
    VALUES('receipt-sql-validator','receipt-sql-address','u',18446744073709551616,'ualpha','2000-01-01','receipt-sql',100,0,0)
    ON CONFLICT (chain_id,block_height,tx_index,event_index,denom) DO NOTHING;
    IF EXISTS (SELECT 1 FROM structs.defusion_current WHERE chain_id='receipt-sql') THEN
        RAISE EXCEPTION 'retired receipt resurrected';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM structs.defusion WHERE chain_id='receipt-sql'
        AND amount_p=18446744073709551616 AND retired_height=101) THEN
        RAISE EXCEPTION 'receipt amount or replay tombstone lost';
    END IF;
END $$;
RESET ROLE;
SET LOCAL ROLE structs_webapp;
SELECT validator_address,delegator_address,defusion_type,amount_p::text,amount::text,denom,completed_at,created_at,
    chain_id,block_height::text,tx_index,event_index,source_validator_address,legacy_observed_height::text,
    reconciled_height::text,pending_state FROM structs.defusion_current WHERE delegator_address='receipt-sql-address';
ROLLBACK;
