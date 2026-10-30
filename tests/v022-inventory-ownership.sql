-- Disposable database only. Works with both the initial ownership migration
-- and its later current-claims replacement. All fixtures roll back.
\set ON_ERROR_STOP on
BEGIN;
DELETE FROM sync_state.sync_cursor;
DELETE FROM structs.current_block;
INSERT INTO sync_state.sync_cursor(chain_id,last_height,last_block_time)
VALUES('ownership-sql',100,'2026-10-30T00:00:00Z');
INSERT INTO structs.current_block(chain,height) VALUES('ownership-sql',100);
DELETE FROM structs.api_refresh_state WHERE model='inventory';
INSERT INTO structs.api_refresh_state(model,source_height,source_time)
VALUES('inventory',100,'2026-10-30T00:00:00Z');
INSERT INTO structs.player(id,primary_address) VALUES
    ('1-990950','ownershipsqla'),('1-990951','ownershipsqlb');
INSERT INTO structs.player_address(address,player_id,status)
VALUES('ownershipsqlretained','1-990950','approved');
INSERT INTO structs.ledger(address,denom,amount_p,direction,action)
VALUES('ownershipsqlretained','ualpha',100,'credit','received');
INSERT INTO structs.api_inventory(owner_type,owner_id,denom,balance) VALUES
    ('address','ownershipsqlretained','ualpha',100),('player','1-990950','ualpha',100);
SET LOCAL ROLE structs_indexer;
DO $$ BEGIN
    IF (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) THEN
        RAISE EXCEPTION 'requires non-superuser indexer';
    END IF;
    IF EXISTS (SELECT 1 FROM structs.api_inventory_reconcile(FALSE)
        WHERE owner_id IN ('1-990950','1-990951','ownershipsqlretained')) THEN
        RAISE EXCEPTION 'correct initial inventory reported drift';
    END IF;
END $$;
RESET ROLE;
UPDATE structs.player_address SET player_id='1-990951' WHERE address='ownershipsqlretained';
SET LOCAL ROLE structs_indexer;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM structs.api_inventory_reconcile(FALSE)
        WHERE owner_id='1-990950' AND api_balance=100 AND COALESCE(ledger_balance,0)=0)
       OR NOT EXISTS (SELECT 1 FROM structs.api_inventory_reconcile(FALSE)
        WHERE owner_id='1-990951' AND COALESCE(api_balance,0)=0 AND ledger_balance=100)
       OR EXISTS (SELECT 1 FROM structs.api_inventory_reconcile(FALSE)
        WHERE owner_id='ownershipsqlretained') THEN
        RAISE EXCEPTION 'reconciliation did not move the claim to its current owner';
    END IF;
END $$;
RESET ROLE;
UPDATE sync_state.sync_cursor SET last_height=101;
SET LOCAL ROLE structs_indexer;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM structs.api_inventory_reconcile(FALSE)) THEN
        RAISE EXCEPTION 'incomplete projection boundary emitted reconciliation results';
    END IF;
END $$;
RESET ROLE;
UPDATE sync_state.sync_cursor SET last_height=100;
UPDATE structs.api_inventory SET owner_id='1-990951' WHERE owner_type='player' AND owner_id='1-990950';
SET LOCAL ROLE structs_indexer;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM structs.api_inventory_reconcile(FALSE)
        WHERE owner_id IN ('1-990950','1-990951','ownershipsqlretained')) THEN
        RAISE EXCEPTION 'repaired inventory still reported drift';
    END IF;
END $$;
ROLLBACK;
