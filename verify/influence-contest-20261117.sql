-- Verify structs-pg:influence-contest-20261117 on pg
BEGIN;
DO $$
BEGIN
 -- Superseded by the explicit official-contest reset. Keep full-plan verify
 -- useful after the rehearsal definition and its initializer are removed.
 IF to_regprocedure('structs.influence_official_contest_initialize()') IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM structs.influence_contest WHERE contest_id=1
   AND chain_id='structstestnet-111' AND start_height=3743186 AND end_height=3957791
   AND scoring_mode='planet_sectors' AND rule_id=1) THEN
   RAISE EXCEPTION 'official contest did not replace the rehearsal';
  END IF;
  RETURN;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM structs.influence_contest c JOIN structs.influence_rule_set r USING(rule_id)
  WHERE c.contest_id=2 AND c.chain_id='structstestnet-111' AND c.start_height=3633541
  AND c.end_height=3649817 AND c.rule_id=1 AND c.scoring_mode='planet_sectors'
  AND r.win_points=100 AND r.claim_points=200) THEN
  RAISE EXCEPTION 'contest 2 configuration differs from the network-wide definition';
 END IF;
 IF EXISTS(SELECT 1 FROM structs.influence_source_cursor
  WHERE chain_id='structstestnet-111' AND coverage_start<=3633541)
  AND NOT EXISTS(SELECT 1 FROM structs.influence_published_build p
   JOIN structs.influence_projection_build b USING(build_id)
   WHERE p.contest_id=2 AND b.contest_id=2 AND b.chain_id='structstestnet-111'
   AND b.state IN ('live','final')) THEN
  RAISE EXCEPTION 'covered contest 2 is missing its published build';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='structs.influence_source_cursor'::regclass
  AND tgname='influence_contest_20261117_initialize' AND tgdeferrable AND tginitdeferred AND tgenabled='O') THEN
  RAISE EXCEPTION 'contest 2 deferred initialization trigger is missing';
 END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
  WHERE p.oid='structs.influence_contest_20261117_initialize()'::regprocedure AND a.grantee=0) THEN
  RAISE EXCEPTION 'contest initializer must not be executable by PUBLIC';
 END IF;
END $$;
ROLLBACK;
