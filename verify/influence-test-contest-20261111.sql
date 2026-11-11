-- Verify structs-pg-test-contests:influence-test-contest-20261111 on pg
BEGIN;
DO $$
DECLARE first_height bigint; cid bigint; n bigint;
BEGIN
 SELECT greatest(3545535::bigint,coverage_start) INTO STRICT first_height
 FROM structs.influence_source_cursor WHERE chain_id='structstestnet-111';
 SELECT count(*),min(contest_id) INTO n,cid FROM structs.influence_contest
 WHERE chain_id='structstestnet-111' AND start_height=first_height AND end_height=3626388 AND rule_id=1;
 IF n<>1 THEN RAISE EXCEPTION 'expected exactly one November 2026 test contest, found %',n; END IF;
 IF NOT EXISTS(SELECT 1 FROM structs.influence_published_build p JOIN structs.influence_projection_build b USING(build_id)
  JOIN structs.influence_contest c ON c.contest_id=p.contest_id JOIN structs.influence_rule_set r USING(rule_id)
  WHERE p.contest_id=cid AND b.state IN ('live','final') AND r.win_points=100 AND r.claim_points=200) THEN
  RAISE EXCEPTION 'test contest is missing its published 100/200 scoring build'; END IF;
END $$;
ROLLBACK;
