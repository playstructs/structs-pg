-- Exercise real Sqitch functions with committed-state boundary fixtures.
\set ON_ERROR_STOP on
BEGIN;
DELETE FROM structs.current_block;
DELETE FROM sync_state.sync_cursor;
DELETE FROM structs.api_refresh_state;
DO $$
DECLARE r RECORD;
BEGIN
    SELECT * INTO r FROM structs.api_readiness(ARRAY['inventory']);
    IF r.data_ready OR r.transaction_ready OR r.height IS NOT NULL THEN
        RAISE EXCEPTION 'missing indexed context was ready';
    END IF;
END $$;
INSERT INTO sync_state.sync_cursor(chain_id,last_height,last_block_time,tip_height,status)
VALUES('structstestnet-111',3352999,'2026-10-29T12:00:00Z',3352999,'current');
INSERT INTO structs.current_block(chain,height,tip_height,status) VALUES('structstestnet-111',3352999,3352999,'current');
INSERT INTO structs.api_refresh_state(model,source_height,source_time,inventory_authority)
VALUES('inventory',3352999,'2026-10-29T12:00:00Z','ledger');
SET LOCAL ROLE structs_webapp;
DO $$
DECLARE r RECORD;
BEGIN
    IF (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) THEN RAISE EXCEPTION 'requires restricted webapp role'; END IF;
    SELECT * INTO r FROM structs.api_readiness(ARRAY['inventory','inventory']);
    IF NOT r.data_ready OR NOT r.transaction_ready OR r.protocol<>'v0.21.0'
        OR r.height<>'3352999' OR cardinality(r.required_models)<>1 THEN
        RAISE EXCEPTION 'compatible pre-H reader failed';
    END IF;
    SELECT * INTO r FROM structs.api_readiness(ARRAY['inventory','work']);
    IF r.data_ready OR r.transaction_ready OR r.height IS NOT NULL
        OR (r.models->'work'->>'ready')::boolean THEN
        RAISE EXCEPTION 'missing projection borrowed cursor readiness';
    END IF;
END $$;
RESET ROLE;
UPDATE sync_state.sync_cursor SET tip_height=3353000;
DO $$
DECLARE r RECORD;
BEGIN
    SELECT * INTO r FROM structs.api_readiness(ARRAY['inventory']);
    IF NOT r.data_ready OR r.transaction_ready OR r.protocol<>'v0.21.0' OR r.observed_protocol<>'v0.22.0' THEN
        RAISE EXCEPTION 'node/indexed activation split was ignored';
    END IF;
END $$;
UPDATE sync_state.sync_cursor SET last_height=3353000,last_block_time='2026-10-29T12:00:05Z';
UPDATE structs.current_block SET height=3353000,tip_height=3353000;
UPDATE structs.api_refresh_state SET source_height=3353000,source_time='2026-10-29T12:00:05Z';
DO $$
BEGIN
    IF (SELECT data_ready FROM structs.api_readiness(ARRAY['inventory'])) THEN
        RAISE EXCEPTION 'v0.22 inventory still using legacy authority was ready';
    END IF;
END $$;
UPDATE structs.api_refresh_state SET inventory_authority='current-claims-v1';
INSERT INTO structs.api_refresh_state(model,source_height,source_time)
VALUES('work',3352999,'2026-10-29T12:00:00Z');
DO $$
DECLARE r RECORD;
BEGIN
    SELECT * INTO r FROM structs.api_readiness(ARRAY['inventory']);
    IF NOT r.data_ready OR NOT r.transaction_ready OR r.protocol<>'v0.22.0' OR r.cache_epoch<>'structs-api-v022-1:v0.22.0' THEN
        RAISE EXCEPTION 'ready liquid projection depends on unrelated incomplete work';
    END IF;
    SELECT * INTO r FROM structs.api_readiness(ARRAY['inventory','work']);
    IF r.data_ready OR r.height<>'3352999' THEN RAISE EXCEPTION 'mixed models stamped at newer height'; END IF;
END $$;
UPDATE structs.api_refresh_state SET source_height=3353000 WHERE model='work';
DO $$
BEGIN
    IF (SELECT data_ready FROM structs.api_readiness(ARRAY['work'])) THEN
        RAISE EXCEPTION 'mismatched source time was ready';
    END IF;
END $$;
UPDATE structs.api_refresh_state SET source_time='2026-10-29T12:00:05Z' WHERE model='work';
UPDATE structs.current_block SET height=3352999;
DO $$
BEGIN
    IF (SELECT data_ready FROM structs.api_readiness(ARRAY['inventory'])) THEN
        RAISE EXCEPTION 'canonical cursor disagreement was ready';
    END IF;
END $$;
UPDATE structs.current_block SET height=3353000;
INSERT INTO sync_state.sync_cursor(chain_id,last_height) VALUES('other-chain',5);
DO $$
BEGIN
    IF (SELECT data_ready FROM structs.api_readiness()) THEN RAISE EXCEPTION 'ambiguous chain context was ready'; END IF;
END $$;
DELETE FROM sync_state.sync_cursor WHERE chain_id='other-chain';
UPDATE sync_state.sync_cursor SET chain_id='unsupported';
UPDATE structs.current_block SET chain='unsupported';
DO $$
BEGIN
    IF (SELECT data_ready OR protocol IS NOT NULL FROM structs.api_readiness()) THEN
        RAISE EXCEPTION 'unknown network inherited testnet activation';
    END IF;
END $$;
ROLLBACK;
