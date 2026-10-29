-- Run only against the disposable Sqitch database. All changes roll back.
\set ON_ERROR_STOP on
BEGIN;
DELETE FROM sync_state.sync_cursor;
INSERT INTO sync_state.sync_cursor(chain_id,last_height,last_block_time)
VALUES ('claims-sql',100,'2026-10-29T12:00:00Z');
INSERT INTO structs.player(id,primary_address) VALUES ('1-996401','claims-sql-address');
INSERT INTO structs.ledger(address,denom,amount_p,direction,action)
VALUES ('claims-sql-address','ualpha.infused',999,'credit','infused');
DELETE FROM structs.api_refresh_state WHERE model='inventory';
INSERT INTO structs.api_refresh_state(model,source_height) VALUES ('inventory',100);
SET LOCAL ROLE structs_indexer;
DO $$ BEGIN
    IF (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) THEN
        RAISE EXCEPTION 'requires non-superuser indexer';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM structs.api_inventory_address_expected(ARRAY['claims-sql-address']::VARCHAR[])
                   WHERE denom='ualpha.infused' AND balance=999) THEN
        RAISE EXCEPTION 'compatible deployment changed the legacy source before rebuild';
    END IF;
    IF (SELECT count(*) FROM structs.api_inventory_address_expected(ARRAY['claims-sql-address']::VARCHAR[],TRUE)
        WHERE balance IS NULL) <> 2 THEN
        RAISE EXCEPTION 'missing native evidence must produce two unknown claims';
    END IF;
    UPDATE structs.api_refresh_state SET inventory_authority='current-claims-v1' WHERE model='inventory';
    IF EXISTS (SELECT 1 FROM structs.api_inventory_address_expected(ARRAY['claims-sql-address']::VARCHAR[])
               WHERE balance IS NOT NULL) THEN
        RAISE EXCEPTION 'activated maintenance still trusts synthetic receipts';
    END IF;
    INSERT INTO sync_state.native_staking_snapshot(chain_id,address,required_height,source_height,bonded,unbonding,fetched_at)
    VALUES ('claims-sql','claims-sql-address',100,100,18446744073709551616,0,NOW());
    IF NOT EXISTS (SELECT 1 FROM structs.api_inventory_address_expected(ARRAY['claims-sql-address']::VARCHAR[])
                   WHERE denom='ualpha.infused' AND balance=18446744073709551616) THEN
        RAISE EXCEPTION 'current claim lost exact precision';
    END IF;
    INSERT INTO structs.api_inventory(owner_type,owner_id,denom,balance)
    VALUES ('address','claims-sql-unknown','ualpha.infused',NULL);
    BEGIN
        INSERT INTO structs.api_inventory(owner_type,owner_id,denom,balance)
        VALUES ('address','claims-sql-unknown','ualpha',NULL);
        RAISE EXCEPTION 'unknown bank balance accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    -- New identities are all unknown rather than borrowing another chain's
    -- complete evidence when more than one cursor is configured.
END $$;
RESET ROLE;
INSERT INTO sync_state.sync_cursor(chain_id,last_height) VALUES ('claims-sql-other',100);
SET LOCAL ROLE structs_indexer;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM structs.api_inventory_address_expected(ARRAY['claims-sql-address']::VARCHAR[])
               WHERE balance IS NOT NULL) THEN
        RAISE EXCEPTION 'ambiguous chain evidence was published';
    END IF;
END $$;
ROLLBACK;
