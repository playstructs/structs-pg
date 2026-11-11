-- Revert structs-pg:influence-single-sector-20261111 from pg
BEGIN;
SELECT structs.influence_lock();
DO $$ BEGIN IF EXISTS(SELECT 1 FROM structs.influence_contest WHERE scoring_mode='single_sector') THEN
 RAISE EXCEPTION 'single-sector contests exist; preserve their rules before reverting single-sector support'; END IF; END $$;
DROP VIEW structs.influence_ranked_standings;
DROP VIEW structs.influence_standings;
CREATE OR REPLACE FUNCTION structs.influence_project_raid(b bigint,rid bigint,p jsonb)
RETURNS void LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE r influence_raid%ROWTYPE; old_holder text; old_sector smallint; new_holder text;
 g text; old_g text; n bigint; existing_sector smallint;
BEGIN
 SELECT * INTO STRICT r FROM influence_raid WHERE raid_id=rid;
 IF NOT r.attribution_complete THEN RAISE EXCEPTION 'incomplete influence attribution'; END IF;
 -- Build membership must already reflect source events through this position.
 IF NOT EXISTS(SELECT 1 FROM influence_member WHERE build_id=b AND player=r.attacker) THEN
  RAISE EXCEPTION 'missing influence membership for %',r.attacker;
 END IF;
 SELECT guild INTO g FROM influence_member WHERE build_id=b AND player=r.attacker;
 INSERT INTO influence_contest_planet VALUES(b,r.planet,r.sector) ON CONFLICT DO NOTHING;
 SELECT sector INTO existing_sector FROM influence_contest_planet WHERE build_id=b AND planet=r.planet;
 IF existing_sector<>r.sector THEN RAISE EXCEPTION 'planet sector changed within influence contest: %',r.planet; END IF;
 IF r.attacker<>r.defender AND r.attacker_guild IS NOT NULL AND r.defender_guild IS NOT NULL AND r.attacker_guild<>r.defender_guild THEN
  new_holder:=r.attacker;
  INSERT INTO influence_player_planet_win VALUES(b,r.attacker,r.planet,r.chain_id,rid) ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n=1 AND g IS NOT NULL THEN
   INSERT INTO influence_guild_planet_win VALUES(b,g,r.planet,1)
   ON CONFLICT(build_id,guild,planet) DO UPDATE SET supporter_count=influence_guild_planet_win.supporter_count+1
   RETURNING supporter_count INTO n;
   IF n=1 THEN PERFORM influence_adjust(b,g,r.sector,1,0,p,'planet_coverage'); END IF;
  END IF;
 END IF;
 SELECT holder,sector INTO old_holder,old_sector FROM influence_planet_claim WHERE build_id=b AND planet=r.planet;
 IF old_holder IS DISTINCT FROM new_holder THEN
  IF old_holder IS NOT NULL THEN
   UPDATE influence_player_sector SET held_planets=held_planets-1 WHERE build_id=b AND player=old_holder AND sector=old_sector;
   SELECT guild INTO old_g FROM influence_member WHERE build_id=b AND player=old_holder;
   PERFORM influence_adjust(b,old_g,old_sector,0,-1,p,'claim_replaced');
  END IF;
  IF new_holder IS NOT NULL THEN
   INSERT INTO influence_player_sector VALUES(b,new_holder,r.sector,1)
   ON CONFLICT(build_id,player,sector) DO UPDATE SET held_planets=influence_player_sector.held_planets+1;
   PERFORM influence_adjust(b,g,r.sector,0,1,p,'claim_acquired');
  END IF;
 END IF;
 INSERT INTO influence_planet_claim VALUES(b,r.planet,r.sector,r.chain_id,rid,new_holder)
 ON CONFLICT(build_id,planet) DO UPDATE SET latest_raid_id=EXCLUDED.latest_raid_id,holder=EXCLUDED.holder;
END $$;

CREATE OR REPLACE FUNCTION structs.influence_finish_block(ch text,h bigint,hash text) RETURNS void
LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE cursor_height bigint;
BEGIN
 PERFORM influence_lock();
 SELECT height INTO STRICT cursor_height FROM influence_source_cursor WHERE chain_id=ch FOR UPDATE;
 IF cursor_height<>h-1 THEN RAISE EXCEPTION 'influence coverage gap: have %, next %',cursor_height,h; END IF;
 UPDATE influence_source_cursor SET height=h,block_hash=hash WHERE chain_id=ch;
 UPDATE influence_projection_build b SET projected_height=least(h,c.end_height),
 state=CASE WHEN h>=c.end_height AND NOT EXISTS(SELECT 1 FROM influence_contest_planet p WHERE p.build_id=b.build_id AND p.sector=0)
 THEN 'final' ELSE 'live' END
 FROM influence_contest c WHERE c.contest_id=b.contest_id AND b.chain_id=ch AND b.state='live' AND b.projected_height<least(h,c.end_height);
END $$;

CREATE OR REPLACE FUNCTION structs.influence_rebuild(cid bigint) RETURNS bigint LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE c influence_contest%ROWTYPE; cur influence_source_cursor%ROWTYPE; bid bigint; stop_h bigint; base_h bigint; e record; p jsonb;
BEGIN
 PERFORM influence_lock();
 SELECT * INTO STRICT c FROM influence_contest WHERE contest_id=cid;
 SELECT * INTO STRICT cur FROM influence_source_cursor WHERE chain_id=c.chain_id;
 IF c.start_height<cur.coverage_start THEN RAISE EXCEPTION 'contest starts before exact influence coverage %',cur.coverage_start; END IF;
 stop_h:=least(cur.height,c.end_height); base_h:=least(c.start_height-1,cur.height);
 INSERT INTO influence_projection_build(contest_id,chain_id,projected_height,state) VALUES(cid,c.chain_id,base_h,'building') RETURNING build_id INTO bid;
 INSERT INTO influence_member
 SELECT DISTINCT ON(player) bid,player,guild FROM influence_membership_history
 WHERE chain_id=c.chain_id AND height<=base_h
 ORDER BY player,height DESC,phase DESC,tx_index DESC,event_index DESC,attribute_index DESC;
 FOR e IN
 SELECT height,phase,tx_index,event_index,0 kind,raid_id,NULL::text player,NULL::text guild,block_time FROM influence_raid
 WHERE chain_id=c.chain_id AND height BETWEEN c.start_height AND stop_h
 UNION ALL
 SELECT height,phase,tx_index,event_index,1,NULL::bigint,player,guild,NULL::timestamptz FROM influence_membership_history
 WHERE chain_id=c.chain_id AND height>base_h AND height<=stop_h AND NOT baseline
 ORDER BY height,phase,tx_index,event_index,kind
 LOOP
  -- Membership event time is persisted separately for exact rebuilt charts.
  IF e.kind=1 THEN SELECT event_time INTO e.block_time FROM influence_membership_history
   WHERE chain_id=c.chain_id AND player=e.player AND height=e.height AND phase=e.phase AND tx_index=e.tx_index AND event_index=e.event_index AND attribute_index=0; END IF;
  p:=jsonb_build_object('height',e.height,'phase',e.phase,'tx_index',e.tx_index,'event_index',e.event_index,'time',e.block_time);
  IF e.kind=0 THEN PERFORM influence_project_raid(bid,e.raid_id,p);
  ELSE PERFORM influence_project_member(bid,e.player,e.guild,p); END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM influence_reconcile(bid) WHERE mismatches<>0) THEN
  RAISE EXCEPTION 'influence rebuild reconciliation failed'; END IF;
 UPDATE influence_projection_build SET projected_height=stop_h,
 state=CASE WHEN stop_h=c.end_height AND NOT EXISTS(SELECT 1 FROM influence_contest_planet WHERE build_id=bid AND sector=0) THEN 'final' ELSE 'live' END WHERE build_id=bid;
 UPDATE influence_projection_build SET state='invalid' WHERE contest_id=cid AND build_id<>bid AND state IN ('live','building');
 INSERT INTO influence_published_build VALUES(cid,bid) ON CONFLICT(contest_id) DO UPDATE SET build_id=EXCLUDED.build_id;
 RETURN bid;
END $$;

CREATE OR REPLACE FUNCTION structs.influence_create_contest(ch text,s bigint,e bigint,r bigint DEFAULT 1)
RETURNS bigint LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE cid bigint; policy jsonb; cur influence_source_cursor%ROWTYPE;
BEGIN
 PERFORM influence_lock();
 SELECT * INTO STRICT cur FROM influence_source_cursor WHERE chain_id=ch;
 IF s<cur.coverage_start THEN RAISE EXCEPTION 'contest starts before exact source coverage %',cur.coverage_start; END IF;
 IF (SELECT count(*) FROM influence_contest WHERE chain_id=ch AND end_height>cur.height)>=8 THEN
  RAISE EXCEPTION 'maximum eight concurrent/future influence contests'; END IF;
 SELECT rs.policy INTO STRICT policy FROM influence_rule_set rs WHERE rule_id=r;
 IF policy<> '{"uniqueness":"planet_per_guild","completed_planets":"retain","eligibility":"cross_guild_at_event","ineligible_success":"clear_claim"}'::jsonb THEN
  RAISE EXCEPTION 'unsupported influence rule semantics'; END IF;
 INSERT INTO influence_contest(chain_id,start_height,end_height,rule_id) VALUES(ch,s,e,r) RETURNING contest_id INTO cid;
 PERFORM influence_rebuild(cid);
 RETURN cid;
END $$;
DROP FUNCTION structs.influence_create_contest(text,bigint,bigint,bigint,text);
ALTER TABLE structs.influence_contest DROP COLUMN scoring_mode;
CREATE VIEW structs.influence_standings AS
 SELECT c.contest_id,b.build_id,b.projected_height,b.state,s.guild,s.sector,
 s.unique_planets,s.held_planets,
 s.unique_planets::numeric*r.win_points+s.held_planets::numeric*r.claim_points AS points,
 NOT EXISTS(SELECT 1 FROM structs.influence_contest_planet p WHERE p.build_id=b.build_id AND p.sector=0) AS sectors_complete
 FROM structs.influence_published_build pub
 JOIN structs.influence_contest c USING(contest_id)
 JOIN structs.influence_projection_build b ON b.build_id=pub.build_id
 JOIN structs.influence_rule_set r USING(rule_id)
 JOIN structs.influence_guild_sector s ON s.build_id=b.build_id;
GRANT SELECT ON structs.influence_standings TO structs_webapp;
COMMIT;
