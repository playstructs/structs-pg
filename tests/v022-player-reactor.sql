-- Disposable Sqitch database only; all fixtures roll back.
\set ON_ERROR_STOP on
BEGIN;
SELECT pg_advisory_xact_lock(hashtext('structs.api_work_refresh'));
DELETE FROM sync_state.sync_cursor;
DELETE FROM structs.current_block;
DELETE FROM structs.api_refresh_state;
INSERT INTO sync_state.sync_cursor(chain_id,last_height,last_block_time,tip_height,status)
VALUES ('structstestnet-111',3353000,'2026-10-29T12:00:00Z',3353000,'current');
INSERT INTO structs.current_block(chain,height,tip_height,status)
VALUES ('structstestnet-111',3353000,3353000,'current');
INSERT INTO structs.api_refresh_state(model,source_height,source_time,inventory_authority)
VALUES ('inventory',3353000,'2026-10-29T12:00:00Z','current-claims-v1');
INSERT INTO structs.guild(id,primary_reactor_id,join_infusion_minimum_p)
VALUES ('0-990989','3-990989',1000000);
INSERT INTO structs.reactor(id,validator,default_commission)
VALUES ('3-990989','reactor-validator',0.5);
INSERT INTO structs.player(id,primary_address,guild_id)
VALUES ('1-990989','reactor-retained-a','0-990989');
INSERT INTO structs.vault(owner_id,address,account_number)
VALUES ('1-990989','reactor-vault',0),('0-990989','reactor-treasury',1);
INSERT INTO structs.player_address(address,player_id,status) VALUES
('reactor-retained-b','1-990989','approved'),('reactor-revoked','1-990989','revoked'),
('reactor-pending','1-990989','pending');
INSERT INTO structs.infusion(destination_id,address,destination_type,player_id,owner_id,fuel_p,defusing_p,power_p,ratio_p,commission)
VALUES ('3-990989','reactor-vault','reactor','1-990989','1-990989',10,999,1,1,0.5),
('3-990989','reactor-retained-a','reactor','1-990989',NULL,20,999,1,1,0.5),
('3-990989','reactor-retained-b','reactor','1-990989','1-990989',30,999,3,1,0.5),
('3-990989','reactor-revoked','reactor','1-990989','1-990989',900,900,900,1,0),
('3-990989','reactor-pending','reactor','1-990989','1-990989',900,900,900,1,0),
('3-990989','reactor-treasury','reactor','1-990989','0-990989',900,900,900,1,0),
('3-990988','reactor-retained-a','reactor','1-990989','1-990989',900,900,900,1,0);
INSERT INTO sync_state.native_staking_snapshot
(chain_id,address,required_height,source_height,bonded,unbonding,fetched_at,positions_complete)
VALUES ('structstestnet-111','reactor-vault',3353000,3353000,9007199254740993,0,NOW(),TRUE),
('structstestnet-111','reactor-retained-a',3353000,3353000,7,0,NOW(),TRUE),
('structstestnet-111','reactor-retained-b',3353000,3353000,0,0,NOW(),TRUE);
INSERT INTO sync_state.native_staking_position(chain_id,address,validator,bonded,unbonding,unbonding_entries)
VALUES ('structstestnet-111','reactor-vault','reactor-validator',9007199254740993,0,0),
('structstestnet-111','reactor-retained-a','reactor-validator',7,0,1);
SET LOCAL ROLE structs_webapp;
DO $$
DECLARE result JSONB;
BEGIN
    IF (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) THEN RAISE EXCEPTION 'requires restricted role'; END IF;
    result := structs.api_player_reactor('1-990989');
    IF result->>'fuel_p' IS DISTINCT FROM '9007199254741000'
        OR result->>'defusing_p' IS DISTINCT FROM '0' THEN
        RAISE EXCEPTION 'native exact balances/completed cooldown: %',result;
    END IF;
    IF result->>'power_p' IS DISTINCT FROM '5' OR result->>'owner_power_p' IS DISTINCT FROM '3' THEN
        RAISE EXCEPTION 'per-position ties-to-even owner power: %',result;
    END IF;
    IF result#>>'{positions_meta,complete}' IS DISTINCT FROM 'true'
        OR result#>>'{positions_meta,eligibility_checked}' IS DISTINCT FROM 'false'
        OR jsonb_array_length(result->'positions')<>3 OR result->>'address' IS NOT NULL
        OR result#>>'{positions,0,address}' IS DISTINCT FROM 'reactor-vault'
        OR result#>>'{positions,1,address}' IS DISTINCT FROM 'reactor-retained-a'
        OR result#>>'{positions,2,fuel_p}' IS DISTINCT FROM '0'
        OR result#>>'{positions,1,unbonding_entries}' IS DISTINCT FROM '1'
        OR result#>>'{positions,0,stored_defusing_p}' IS DISTINCT FROM '999' THEN
        RAISE EXCEPTION 'coverage, ownership, deterministic order or raw diagnostics: %',result;
    END IF;
    IF structs.api_player_reactor('1-0') IS NOT NULL THEN RAISE EXCEPTION 'missing player synthesized'; END IF;
END $$;
RESET ROLE;
-- Rounding the aggregate instead of each position is wrong in both directions.
UPDATE structs.infusion SET power_p=0 WHERE destination_id='3-990989' AND address='reactor-retained-b';
DO $$ DECLARE r JSONB := structs.api_player_reactor('1-990989'); BEGIN
    IF r->>'power_p' IS DISTINCT FROM '2' OR r->>'owner_power_p' IS DISTINCT FROM '2' THEN
        RAISE EXCEPTION 'rounded combined power instead of each even tie: %',r;
    END IF;
END $$;
UPDATE structs.infusion SET power_p=3 WHERE destination_id='3-990989' AND address IN ('reactor-vault','reactor-retained-a');
DO $$ DECLARE r JSONB := structs.api_player_reactor('1-990989'); BEGIN
    IF r->>'power_p' IS DISTINCT FROM '6' OR r->>'owner_power_p' IS DISTINCT FROM '2' THEN
        RAISE EXCEPTION 'rounded combined power instead of each odd tie: %',r;
    END IF;
END $$;
UPDATE structs.infusion SET power_p=1 WHERE destination_id='3-990989' AND address IN ('reactor-vault','reactor-retained-a');
UPDATE structs.infusion SET power_p=3 WHERE destination_id='3-990989' AND address='reactor-retained-b';
-- The old stored owner is not authority for a new address owner. Native stake
-- remains hers; stored power cannot be credited to her until reconciliation.
UPDATE structs.infusion SET owner_id='1-990988'
WHERE destination_id='3-990989' AND address='reactor-retained-a';
DO $$ DECLARE r JSONB := structs.api_player_reactor('1-990989'); BEGIN
    IF r->>'fuel_p' IS DISTINCT FROM '9007199254741000' OR r->>'power_p' IS NOT NULL
        OR r#>>'{positions_meta,power_ready}' IS DISTINCT FROM 'false' THEN
        RAISE EXCEPTION 'cached owner was trusted: %',r;
    END IF;
END $$;
UPDATE structs.infusion SET owner_id=NULL WHERE destination_id='3-990989' AND address='reactor-retained-a';
UPDATE sync_state.native_staking_snapshot SET positions_complete=FALSE WHERE address='reactor-retained-b';
DO $$ DECLARE r JSONB := structs.api_player_reactor('1-990989'); BEGIN
    IF r->>'fuel_p' IS NOT NULL OR r->>'defusing_p' IS NOT NULL OR r->>'power_p' IS DISTINCT FROM '5'
        OR r#>>'{positions_meta,complete}' IS DISTINCT FROM 'false' THEN
        RAISE EXCEPTION 'legacy evidence became a known zero: %',r;
    END IF;
END $$;
UPDATE sync_state.native_staking_snapshot SET positions_complete=TRUE,source_height=3352999 WHERE address='reactor-retained-b';
DO $$ DECLARE r JSONB := structs.api_player_reactor('1-990989'); BEGIN
    IF r->>'fuel_p' IS NOT NULL THEN RAISE EXCEPTION 'stale position published: %',r; END IF;
END $$;
UPDATE sync_state.native_staking_snapshot SET source_height=3353000 WHERE address='reactor-retained-b';
DELETE FROM structs.api_refresh_state WHERE model='inventory';
DO $$ DECLARE r JSONB := structs.api_player_reactor('1-990989'); BEGIN
    IF r->>'fuel_p' IS NOT NULL OR r->>'power_p' IS NOT NULL
        OR r#>>'{positions_meta,reason}' IS DISTINCT FROM 'snapshot_unavailable' THEN
        RAISE EXCEPTION 'missing projection evidence published: %',r;
    END IF;
END $$;
INSERT INTO structs.api_refresh_state(model,source_height,source_time,inventory_authority)
VALUES ('inventory',3353000,'2026-10-29T12:00:00Z','current-claims-v1');
DELETE FROM structs.vault WHERE owner_id='1-990989';
DO $$ DECLARE r JSONB := structs.api_player_reactor('1-990989'); BEGIN
    IF r->>'fuel_p' IS NOT NULL OR r#>>'{positions_meta,reason}' IS DISTINCT FROM 'vault_unindexed' THEN
        RAISE EXCEPTION 'missing vault became complete ownership: %',r;
    END IF;
END $$;
INSERT INTO structs.vault(owner_id,address,account_number) VALUES ('1-990989','reactor-vault',0);
INSERT INTO structs.player_address(address,player_id,status)
SELECT 'reactor-overflow-'||n,'1-990989','approved' FROM generate_series(1,1024) n;
DO $$ DECLARE r JSONB := structs.api_player_reactor('1-990989'); BEGIN
    IF r->>'fuel_p' IS NOT NULL OR r->>'power_p' IS NOT NULL OR r->'positions'<>'[]'::jsonb
        OR r#>>'{positions_meta,reason}' IS DISTINCT FROM 'address_limit' THEN
        RAISE EXCEPTION 'partial oversized address list published: %',r;
    END IF;
END $$;
ROLLBACK;
