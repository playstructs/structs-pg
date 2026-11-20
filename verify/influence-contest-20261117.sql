-- Verify structs-pg:influence-contest-20261117 on pg
-- Retired data seed: before the official reset, arbitrary existing rehearsal
-- data is deliberately untouched. Do not demand one particular test ID/rule.
BEGIN;
SELECT contest_id,chain_id,start_height,end_height,rule_id,scoring_mode
 FROM structs.influence_contest WHERE false;
DO $$
BEGIN
 IF to_regprocedure('structs.influence_official_contest_initialize()') IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM structs.influence_contest WHERE contest_id=1
   AND chain_id='structstestnet-111' AND start_height=3743186 AND end_height=3957791
   AND scoring_mode='planet_sectors' AND rule_id=1) THEN
   RAISE EXCEPTION 'official contest did not replace the rehearsal';
  END IF;
 END IF;
END $$;
ROLLBACK;
