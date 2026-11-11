-- Revert structs-pg-test-contests:influence-test-contest-20261111 from pg
-- Preserve source facts and every other contest. A scored test must be retained
-- or handled explicitly by an operator; a schema rollback cannot erase it.
BEGIN;
SELECT structs.influence_lock();
DO $$
DECLARE first_height bigint; cid bigint; n bigint; builds bigint[];
BEGIN
 SELECT greatest(3545535::bigint,coverage_start) INTO STRICT first_height
 FROM structs.influence_source_cursor WHERE chain_id='structstestnet-111';
 SELECT count(*),min(contest_id) INTO n,cid FROM structs.influence_contest
 WHERE chain_id='structstestnet-111' AND start_height=first_height AND end_height=3626388 AND rule_id=1;
 IF n<>1 THEN RAISE EXCEPTION 'cannot identify exactly one test contest to revert'; END IF;
 SELECT array_agg(build_id) INTO builds FROM structs.influence_projection_build WHERE contest_id=cid;
 IF EXISTS(SELECT 1 FROM structs.influence_player_planet_win WHERE build_id=ANY(builds))
  OR EXISTS(SELECT 1 FROM structs.influence_planet_claim WHERE build_id=ANY(builds))
  OR EXISTS(SELECT 1 FROM structs.influence_score_change WHERE build_id=ANY(builds)) THEN
  RAISE EXCEPTION 'test contest contains raid/score data; refusing destructive revert'; END IF;
 DELETE FROM structs.influence_published_build WHERE contest_id=cid;
 DELETE FROM structs.influence_checkpoint WHERE build_id=ANY(builds);
 DELETE FROM structs.influence_rollup_coverage WHERE build_id=ANY(builds);
 DELETE FROM structs.influence_guild_sector WHERE build_id=ANY(builds);
 DELETE FROM structs.influence_player_sector WHERE build_id=ANY(builds);
 DELETE FROM structs.influence_guild_planet_win WHERE build_id=ANY(builds);
 DELETE FROM structs.influence_contest_planet WHERE build_id=ANY(builds);
 DELETE FROM structs.influence_member WHERE build_id=ANY(builds);
 DELETE FROM structs.influence_projection_build WHERE contest_id=cid;
 DELETE FROM structs.influence_contest WHERE contest_id=cid;
END $$;
COMMIT;
