-- Deploy structs-pg-test-contests:influence-test-contest-single-sector-20261111
-- One-time owner operation on this rehearsal only. Source facts and contest
-- identity/bounds/rule stay intact. Ordinary contest updates remain forbidden.
BEGIN;
SELECT structs.influence_lock();
DO $$
DECLARE first_height bigint; cid bigint; n bigint; old_build bigint; new_build bigint; cur_height bigint;
BEGIN
 SELECT greatest(3545535::bigint,coverage_start),height INTO STRICT first_height,cur_height
 FROM structs.influence_source_cursor WHERE chain_id='structstestnet-111';
 SELECT count(*),min(contest_id) INTO n,cid FROM structs.influence_contest
 WHERE chain_id='structstestnet-111' AND start_height=first_height AND end_height=3626388 AND rule_id=1;
 IF n<>1 THEN RAISE EXCEPTION 'cannot identify exactly one November 2026 test contest'; END IF;
 SELECT p.build_id INTO STRICT old_build FROM structs.influence_published_build p
 JOIN structs.influence_projection_build b USING(build_id)
 JOIN structs.influence_contest c ON c.contest_id=p.contest_id
 WHERE p.contest_id=cid AND b.state='live' AND c.scoring_mode='planet_sectors';
 IF cur_height>=3626388 THEN RAISE EXCEPTION 'cannot change a completed test contest'; END IF;
 IF EXISTS(SELECT 1 FROM structs.influence_raid WHERE chain_id='structstestnet-111'
  AND height BETWEEN first_height AND least(cur_height,3626388) AND sector<>0) THEN
  RAISE EXCEPTION 'test contest has known source sectors; refusing to change its scoring mode'; END IF;
 -- The advisory lock serializes the writer, and ALTER TABLE takes a table lock.
 -- Disabling/re-enabling this one trigger is transactional, including failures.
 ALTER TABLE structs.influence_contest DISABLE TRIGGER influence_contest_immutable;
 UPDATE structs.influence_contest SET scoring_mode='single_sector' WHERE contest_id=cid;
 ALTER TABLE structs.influence_contest ENABLE TRIGGER influence_contest_immutable;
 new_build:=structs.influence_rebuild(cid);
 IF EXISTS(
  SELECT 1 FROM (SELECT guild,sector,unique_planets,held_planets FROM structs.influence_guild_sector WHERE build_id=old_build) a
  FULL JOIN (SELECT guild,sector,unique_planets,held_planets FROM structs.influence_guild_sector WHERE build_id=new_build) b USING(guild,sector)
  WHERE coalesce(a.unique_planets,0)<>coalesce(b.unique_planets,0) OR coalesce(a.held_planets,0)<>coalesce(b.held_planets,0)
 ) THEN RAISE EXCEPTION 'test contest conversion changed its existing score'; END IF;
 RAISE NOTICE 'test contest % now uses single_sector, published build %',cid,new_build;
END $$;
COMMIT;
