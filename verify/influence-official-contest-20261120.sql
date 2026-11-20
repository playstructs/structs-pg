-- Verify structs-pg:influence-official-contest-20261120 on pg
BEGIN;
DO $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM structs.influence_contest c JOIN structs.influence_rule_set r USING(rule_id)
  WHERE c.contest_id=1 AND c.chain_id='structstestnet-111' AND c.start_height=3743186
  AND c.end_height=3957791 AND c.scoring_mode='planet_sectors' AND c.rule_id=1
  AND r.win_points=100 AND r.claim_points=200
  AND r.policy='{"uniqueness":"planet_per_guild","completed_planets":"retain","eligibility":"cross_guild_at_event","ineligible_success":"clear_claim"}'::jsonb) THEN
  RAISE EXCEPTION 'official contest 1 configuration is incorrect';
 END IF;
 IF EXISTS(SELECT 1 FROM structs.influence_contest WHERE chain_id='structstestnet-111'
  AND end_height IN (3626388,3649817)) THEN
  RAISE EXCEPTION 'rehearsal contests were not removed';
 END IF;
 IF to_regprocedure('structs.influence_contest_20261117_initialize()') IS NOT NULL
  OR EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='influence_contest_20261117_initialize'
   AND tgrelid='structs.influence_source_cursor'::regclass) THEN
  RAISE EXCEPTION 'old test-contest initializer must be removed';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='structs.influence_source_cursor'::regclass
  AND tgname='influence_official_contest_initialize' AND tgdeferrable AND tginitdeferred AND tgenabled='O') THEN
  RAISE EXCEPTION 'official contest deferred initializer is missing';
 END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
  WHERE p.oid='structs.influence_official_contest_initialize()'::regprocedure
  AND a.grantee IN (0,(SELECT oid FROM pg_roles WHERE rolname='structs_indexer'),
   (SELECT oid FROM pg_roles WHERE rolname='structs_webapp'))) THEN
  RAISE EXCEPTION 'official contest initializer must remain owner-only';
 END IF;
 IF EXISTS(SELECT 1 FROM structs.influence_source_cursor
  WHERE chain_id='structstestnet-111' AND coverage_start<=3743186)
  AND NOT EXISTS(SELECT 1 FROM structs.influence_published_build p
   JOIN structs.influence_projection_build b USING(build_id)
   WHERE p.contest_id=1 AND b.contest_id=1 AND b.chain_id='structstestnet-111'
   AND b.state IN ('live','final')) THEN
  RAISE EXCEPTION 'covered official contest is missing its published build';
 END IF;
 IF EXISTS(SELECT 1 FROM structs.influence_score_change_1000 a
  LEFT JOIN structs.influence_projection_build b USING(build_id) WHERE b.build_id IS NULL) THEN
  RAISE EXCEPTION 'old test aggregates remain';
 END IF;
END $$;
SELECT 1/has_table_privilege('structs_webapp','structs.influence_score_change_1000','SELECT')::int;
ROLLBACK;
