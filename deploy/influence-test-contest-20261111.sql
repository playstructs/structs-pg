-- Deploy structs-pg-test-contests:influence-test-contest-20261111 to pg
-- Apply the optional sqitch.test-contests.plan AFTER deploying the main schema
-- and starting the matching writer. Ordinary schema deployments do not seed it.
-- Observed structstestnet-111 H=3545534 at 2026-11-11T20:21:25.639412219Z.
-- The previous 10,000 blocks averaged 5.3270449192 seconds/block.
-- H=3626388 estimates Monday 2026-11-16 15:00 America/Toronto (20:00 UTC).
BEGIN;
SELECT structs.influence_lock();
DO $$
DECLARE cur structs.influence_source_cursor%ROWTYPE; first_height bigint; cid bigint;
BEGIN
 SELECT * INTO cur FROM structs.influence_source_cursor WHERE chain_id='structstestnet-111';
 IF NOT FOUND OR cur.height<cur.coverage_start THEN
  RAISE EXCEPTION 'start the influence writer on structstestnet-111 and ingest at least one block before registering this test contest'; END IF;
 IF NOT EXISTS(SELECT 1 FROM structs.current_block b JOIN sync_state.sync_cursor s ON s.chain_id=b.chain
  WHERE b.chain=cur.chain_id AND b.height=cur.height AND s.last_height=cur.height AND s.last_block_hash=cur.block_hash) THEN
  RAISE EXCEPTION 'influence coverage must match the canonical sync cursor before registering this test contest'; END IF;
 IF cur.height>=3626388 THEN RAISE EXCEPTION 'the November 2026 test contest window has ended'; END IF;
 IF NOT EXISTS(SELECT 1 FROM structs.influence_rule_set WHERE rule_id=1 AND win_points=100 AND claim_points=200) THEN
  RAISE EXCEPTION 'this test contest requires the default 100/200 rule'; END IF;
 first_height:=greatest(3545535::bigint,cur.coverage_start);
 IF EXISTS(SELECT 1 FROM structs.influence_contest WHERE chain_id=cur.chain_id
  AND start_height=first_height AND end_height=3626388 AND rule_id=1) THEN
  RAISE EXCEPTION 'a matching test contest already exists; refusing duplicate registration'; END IF;
 cid:=structs.influence_create_contest(cur.chain_id,first_height,3626388,1);
 RAISE NOTICE 'registered test contest % on %, inclusive blocks %..3626388',cid,cur.chain_id,first_height;
END $$;
COMMIT;
