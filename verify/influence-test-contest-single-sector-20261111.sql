BEGIN;
DO $$
DECLARE first_height bigint;
BEGIN
 SELECT greatest(3545535::bigint,coverage_start) INTO STRICT first_height
 FROM structs.influence_source_cursor WHERE chain_id='structstestnet-111';
 IF (SELECT count(*) FROM structs.influence_contest c
  JOIN structs.influence_published_build p USING(contest_id)
  JOIN structs.influence_projection_build b ON b.build_id=p.build_id
  WHERE c.chain_id='structstestnet-111' AND c.start_height=first_height AND c.end_height=3626388
  AND c.rule_id=1 AND c.scoring_mode='single_sector' AND b.state IN ('live','final'))<>1 THEN
  RAISE EXCEPTION 'expected one published single-sector November 2026 test contest'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='structs.influence_contest'::regclass
  AND tgname='influence_contest_immutable' AND tgenabled='O') THEN
  RAISE EXCEPTION 'contest immutability trigger must remain enabled'; END IF;
END $$;
ROLLBACK;
