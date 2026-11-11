-- Deploy structs-pg:influence-projector-20261111 to pg
BEGIN;
SET LOCAL search_path=structs,public,pg_temp;
ALTER TABLE structs.influence_raid ADD COLUMN source jsonb NOT NULL;
ALTER TABLE structs.influence_membership_history ADD COLUMN event_time timestamptz NOT NULL DEFAULT 'epoch';

CREATE FUNCTION structs.influence_lock() RETURNS void LANGUAGE sql AS $$
 SELECT pg_advisory_xact_lock(hashtextextended('structs.influence.writer',0))
$$;

CREATE FUNCTION structs.influence_immutable_source() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' OR current_setting('structs.influence_recovery',true) IS DISTINCT FROM 'on' THEN
  RAISE EXCEPTION 'influence sources are immutable; use coordinated influence rewind'; END IF;
 RETURN OLD;
END $$;
CREATE TRIGGER influence_raid_immutable BEFORE UPDATE OR DELETE ON structs.influence_raid
 FOR EACH ROW EXECUTE FUNCTION structs.influence_immutable_source();
CREATE TRIGGER influence_membership_immutable BEFORE UPDATE OR DELETE ON structs.influence_membership_history
 FOR EACH ROW EXECUTE FUNCTION structs.influence_immutable_source();

CREATE FUNCTION structs.influence_adjust(b bigint,g text,s smallint,u bigint,c bigint,p jsonb,why text)
RETURNS void LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE next_leg integer;
BEGIN
 IF g IS NULL OR (u=0 AND c=0) THEN RETURN; END IF;
 INSERT INTO influence_guild_sector VALUES(b,g,s,0,0) ON CONFLICT DO NOTHING;
 UPDATE influence_guild_sector SET unique_planets=unique_planets+u,held_planets=held_planets+c
 WHERE build_id=b AND guild=g AND sector=s;
 SELECT coalesce(max(leg)+1,0) INTO next_leg FROM influence_score_change
 WHERE build_id=b AND height=(p->>'height')::bigint AND phase=(p->>'phase')::smallint
 AND tx_index=(p->>'tx_index')::int AND event_index=(p->>'event_index')::int AND attribute_index=0;
 INSERT INTO influence_score_change(build_id,height,phase,tx_index,event_index,attribute_index,leg,
 guild,sector,unique_delta,claim_delta,reason,block_time)
 VALUES(b,(p->>'height')::bigint,(p->>'phase')::smallint,(p->>'tx_index')::int,
 (p->>'event_index')::int,0,next_leg,g,s,u,c,why,(p->>'time')::timestamptz);
END $$;

CREATE FUNCTION structs.influence_project_member(b bigint,who text,new_guild text,p jsonb)
RETURNS void LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE old_guild text; d record;
BEGIN
 new_guild:=nullif(new_guild,'');
 SELECT guild INTO old_guild FROM influence_member WHERE build_id=b AND player=who;
 INSERT INTO influence_member VALUES(b,who,new_guild) ON CONFLICT(build_id,player) DO UPDATE SET guild=EXCLUDED.guild;
 IF old_guild IS NOT DISTINCT FROM new_guild THEN RETURN; END IF;
 FOR d IN
 WITH moved AS MATERIALIZED(SELECT planet FROM influence_player_planet_win WHERE build_id=b AND player=who),
 removed AS(DELETE FROM influence_guild_planet_win w USING moved m
 WHERE w.build_id=b AND w.guild=old_guild AND w.planet=m.planet AND w.supporter_count=1 RETURNING w.planet),
 reduced AS(UPDATE influence_guild_planet_win w SET supporter_count=w.supporter_count-1 FROM moved m
 WHERE w.build_id=b AND w.guild=old_guild AND w.planet=m.planet AND w.supporter_count>1 RETURNING w.planet),
 added AS(INSERT INTO influence_guild_planet_win SELECT b,new_guild,planet,1 FROM moved WHERE new_guild IS NOT NULL ORDER BY planet
 ON CONFLICT(build_id,guild,planet) DO UPDATE SET supporter_count=influence_guild_planet_win.supporter_count+1
 RETURNING planet,supporter_count),
 changes AS(SELECT old_guild guild,planet,-1::bigint n FROM removed
 UNION ALL SELECT new_guild,planet,1::bigint FROM added WHERE supporter_count=1)
 SELECT x.guild,t.sector,sum(x.n)::bigint n FROM changes x JOIN influence_contest_planet t ON t.build_id=b AND t.planet=x.planet
 GROUP BY x.guild,t.sector ORDER BY x.guild,t.sector
 LOOP PERFORM influence_adjust(b,d.guild,d.sector,d.n,0,p,'membership_coverage'); END LOOP;
 FOR d IN SELECT sector,held_planets FROM influence_player_sector WHERE build_id=b AND player=who AND held_planets>0 ORDER BY sector LOOP
  PERFORM influence_adjust(b,old_guild,d.sector,0,-d.held_planets,p,'membership_claim');
  PERFORM influence_adjust(b,new_guild,d.sector,0,d.held_planets,p,'membership_claim');
 END LOOP;
END $$;

CREATE FUNCTION structs.influence_project_raid(b bigint,rid bigint,p jsonb)
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

CREATE FUNCTION structs.influence_record_member(p jsonb,who text,new_guild text)
RETURNS void LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE prev text; seen boolean; b record;
BEGIN
 PERFORM influence_lock();
 IF NOT EXISTS(SELECT 1 FROM influence_source_cursor WHERE chain_id=p->>'chain' AND height=(p->>'height')::bigint-1) THEN
  RAISE EXCEPTION 'membership fact is outside the next canonical block'; END IF;
 new_guild:=nullif(new_guild,'');
 SELECT guild INTO prev FROM influence_membership_history WHERE chain_id=p->>'chain' AND player=who
 ORDER BY height DESC,phase DESC,tx_index DESC,event_index DESC,attribute_index DESC LIMIT 1;
 seen:=FOUND;
 IF seen AND prev IS NOT DISTINCT FROM new_guild THEN RETURN; END IF;
 INSERT INTO influence_membership_history VALUES(p->>'chain',who,(p->>'height')::bigint,(p->>'phase')::smallint,
 (p->>'tx_index')::int,(p->>'event_index')::int,0,new_guild,false,(p->>'time')::timestamptz);
 FOR b IN SELECT x.build_id FROM influence_projection_build x JOIN influence_contest c USING(contest_id)
 WHERE x.chain_id=p->>'chain' AND x.state='live' AND x.projected_height<(p->>'height')::bigint
 AND c.end_height>=(p->>'height')::bigint ORDER BY x.build_id LOOP
  PERFORM influence_project_member(b.build_id,who,new_guild,p);
 END LOOP;
END $$;

CREATE FUNCTION structs.influence_record_raid(p jsonb,f jsonb)
RETURNS bigint LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE rid bigint; b record; existing influence_raid%ROWTYPE;
BEGIN
 PERFORM influence_lock();
 IF NOT EXISTS(SELECT 1 FROM influence_source_cursor WHERE chain_id=p->>'chain' AND height=(p->>'height')::bigint-1) THEN
  RAISE EXCEPTION 'raid fact is outside the next canonical block'; END IF;
 INSERT INTO influence_raid(chain_id,height,phase,tx_index,event_index,attribute_index,msg_index,block_hash,block_time,
 attacker,defender,attacker_guild,defender_guild,planet,sector,attribution_complete,payload_hash,source)
 VALUES(p->>'chain',(p->>'height')::bigint,(p->>'phase')::smallint,(p->>'tx_index')::int,(p->>'event_index')::int,0,
 (p->>'msg_index')::int,p->>'hash',(p->>'time')::timestamptz,f->>'attacker',f->>'defender',
 nullif(f->>'attacker_guild',''),nullif(f->>'defender_guild',''),f->>'planet',(f->>'sector')::smallint,true,md5(f::text),f)
 ON CONFLICT(chain_id,height,phase,tx_index,event_index,attribute_index) DO NOTHING RETURNING raid_id INTO rid;
 IF rid IS NULL THEN
  SELECT * INTO STRICT existing FROM influence_raid WHERE chain_id=p->>'chain' AND height=(p->>'height')::bigint
  AND phase=(p->>'phase')::smallint AND tx_index=(p->>'tx_index')::int AND event_index=(p->>'event_index')::int AND attribute_index=0;
  rid:=existing.raid_id;
  IF existing.source IS DISTINCT FROM f OR existing.block_hash IS DISTINCT FROM p->>'hash'
   OR existing.block_time IS DISTINCT FROM (p->>'time')::timestamptz
   OR existing.msg_index IS DISTINCT FROM (p->>'msg_index')::int THEN
   RAISE EXCEPTION 'conflicting influence source replay'; END IF;
  RETURN rid;
 END IF;
 FOR b IN SELECT x.build_id FROM influence_projection_build x JOIN influence_contest c USING(contest_id)
 WHERE x.chain_id=p->>'chain' AND x.state='live' AND x.projected_height<(p->>'height')::bigint
 AND (p->>'height')::bigint BETWEEN c.start_height AND c.end_height ORDER BY x.build_id LOOP
  PERFORM influence_project_raid(b.build_id,rid,p);
 END LOOP;
 RETURN rid;
END $$;

CREATE FUNCTION structs.influence_finish_block(ch text,h bigint,hash text) RETURNS void
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

CREATE FUNCTION structs.influence_rebuild(cid bigint) RETURNS bigint LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
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

CREATE FUNCTION structs.influence_begin_block(ch text,h bigint,hash text,t timestamptz,reconcile boolean DEFAULT false)
RETURNS boolean LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE cur influence_source_cursor%ROWTYPE; boundary bigint; observed bigint;
BEGIN
 PERFORM influence_lock();
 SELECT * INTO cur FROM influence_source_cursor WHERE chain_id=ch FOR UPDATE;
 IF NOT FOUND THEN
  boundary:=CASE WHEN reconcile THEN h ELSE h-1 END;
  SELECT height INTO observed FROM current_block WHERE chain=ch;
  IF (observed IS NULL AND boundary<>0) OR (observed IS NOT NULL AND observed<>boundary) THEN
   RAISE EXCEPTION 'influence bootstrap requires verified current-state boundary %, observed %',boundary,observed;
  END IF;
  INSERT INTO influence_source_cursor VALUES(ch,boundary+1,boundary,CASE WHEN reconcile THEN hash ELSE '' END);
  INSERT INTO influence_membership_history
   SELECT ch,id,boundary,3,-1,0,0,nullif(guild_id,''),true,t FROM player;
  RETURN NOT reconcile;
 END IF;
 IF reconcile AND cur.height<>h THEN
  RAISE EXCEPTION 'influence current-boundary reconciliation requires matching source cursor'; END IF;
 IF cur.height=h THEN
  IF cur.block_hash<>hash THEN RAISE EXCEPTION 'influence block hash conflict at %',h; END IF;
  RETURN false;
 END IF;
 IF cur.height<>h-1 THEN RAISE EXCEPTION 'influence noncontiguous block: have %, received %',cur.height,h; END IF;
 RETURN true;
END $$;

CREATE FUNCTION structs.influence_create_contest(ch text,s bigint,e bigint,r bigint DEFAULT 1)
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

CREATE FUNCTION structs.influence_immutable_config() RETURNS trigger LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
BEGIN
 IF TG_TABLE_NAME='influence_rule_set' THEN
  IF EXISTS(SELECT 1 FROM influence_contest WHERE rule_id=OLD.rule_id) THEN RAISE EXCEPTION 'referenced influence rules are immutable'; END IF;
 ELSE RAISE EXCEPTION 'influence contest bounds/rules are immutable; create another contest'; END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;
CREATE TRIGGER influence_rule_immutable BEFORE UPDATE OR DELETE ON influence_rule_set
 FOR EACH ROW EXECUTE FUNCTION influence_immutable_config();
CREATE TRIGGER influence_contest_immutable BEFORE UPDATE ON influence_contest
 FOR EACH ROW EXECUTE FUNCTION influence_immutable_config();

CREATE FUNCTION structs.influence_reconcile(b bigint)
RETURNS TABLE(check_name text,mismatches bigint) LANGUAGE sql STABLE SET search_path=structs,pg_temp AS $$
 WITH expected AS(
 SELECT p.planet,m.guild,count(*) n FROM influence_player_planet_win p JOIN influence_member m USING(build_id,player)
 WHERE p.build_id=b AND m.guild IS NOT NULL GROUP BY p.planet,m.guild),
 support_diff AS(
 SELECT 1 FROM expected e FULL JOIN (SELECT * FROM influence_guild_planet_win WHERE build_id=b) a USING(planet,guild)
 WHERE e.n IS DISTINCT FROM a.supporter_count),
 counts AS(
 SELECT w.guild,p.sector,count(*) u,0::bigint c FROM influence_guild_planet_win w JOIN influence_contest_planet p USING(build_id,planet)
 WHERE w.build_id=b GROUP BY w.guild,p.sector
 UNION ALL SELECT m.guild,c.sector,0::bigint,count(*) FROM influence_planet_claim c
 JOIN influence_member m ON m.build_id=c.build_id AND m.player=c.holder
 WHERE c.build_id=b AND m.guild IS NOT NULL GROUP BY m.guild,c.sector),
 totals AS(SELECT guild,sector,sum(u)::bigint u,sum(c)::bigint c FROM counts GROUP BY guild,sector),
 balance_diff AS(SELECT 1 FROM totals e FULL JOIN (SELECT * FROM influence_guild_sector WHERE build_id=b) a USING(guild,sector)
 WHERE coalesce(e.u,0)<>coalesce(a.unique_planets,0) OR coalesce(e.c,0)<>coalesce(a.held_planets,0)),
 personal AS(SELECT holder player,sector,count(*) c FROM influence_planet_claim WHERE build_id=b AND holder IS NOT NULL GROUP BY holder,sector),
 personal_diff AS(SELECT 1 FROM personal e FULL JOIN(SELECT * FROM influence_player_sector WHERE build_id=b) a USING(player,sector)
 WHERE coalesce(e.c,0)<>coalesce(a.held_planets,0)),
 deltas AS(SELECT guild,sector,sum(unique_delta) u,sum(claim_delta) c FROM influence_score_change WHERE build_id=b GROUP BY guild,sector),
 delta_diff AS(SELECT 1 FROM deltas e FULL JOIN(SELECT * FROM influence_guild_sector WHERE build_id=b) a USING(guild,sector)
 WHERE coalesce(e.u,0)<>coalesce(a.unique_planets,0) OR coalesce(e.c,0)<>coalesce(a.held_planets,0))
 SELECT 'support'::text,count(*) FROM support_diff
 UNION ALL SELECT 'guild_balance',count(*) FROM balance_diff
 UNION ALL SELECT 'player_claims',count(*) FROM personal_diff
 UNION ALL SELECT 'history_balance',count(*) FROM delta_diff
$$;

CREATE FUNCTION structs.influence_rewind(ch text,h bigint,hash text)
RETURNS void LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE cur influence_source_cursor%ROWTYPE; b record; c record; recovery_setting text;
BEGIN
 PERFORM influence_lock();
 SELECT * INTO STRICT cur FROM influence_source_cursor WHERE chain_id=ch;
 IF h<cur.coverage_start-1 OR h>cur.height THEN RAISE EXCEPTION 'rewind outside influence coverage'; END IF;
 IF NOT EXISTS(SELECT 1 FROM current_block WHERE chain=ch AND height=h) THEN
  RAISE EXCEPTION 'restore canonical base tables/current_block to target height before influence rewind'; END IF;
 -- Invalidate before deleting any source. Published results touching the rewind
 -- disappear until their replacement build is complete in this transaction.
 FOR b IN SELECT * FROM influence_projection_build WHERE chain_id=ch AND projected_height>h ORDER BY build_id LOOP
  DELETE FROM influence_published_build WHERE build_id=b.build_id;
  DELETE FROM influence_rollup_coverage WHERE build_id=b.build_id;
  DELETE FROM influence_checkpoint WHERE build_id=b.build_id;
  DELETE FROM influence_score_change WHERE build_id=b.build_id;
  DELETE FROM influence_guild_sector WHERE build_id=b.build_id;
  DELETE FROM influence_player_sector WHERE build_id=b.build_id;
  DELETE FROM influence_planet_claim WHERE build_id=b.build_id;
  DELETE FROM influence_guild_planet_win WHERE build_id=b.build_id;
  DELETE FROM influence_player_planet_win WHERE build_id=b.build_id;
  DELETE FROM influence_contest_planet WHERE build_id=b.build_id;
  DELETE FROM influence_member WHERE build_id=b.build_id;
  UPDATE influence_projection_build SET state='invalid' WHERE build_id=b.build_id;
 END LOOP;
 recovery_setting:=coalesce(current_setting('structs.influence_recovery',true),'off');
 PERFORM set_config('structs.influence_recovery','on',true);
 DELETE FROM influence_raid WHERE chain_id=ch AND height>h;
 DELETE FROM influence_membership_history WHERE chain_id=ch AND height>h;
 PERFORM set_config('structs.influence_recovery',recovery_setting,true);
 UPDATE influence_source_cursor SET height=h,block_hash=hash WHERE chain_id=ch;
 FOR c IN SELECT contest_id FROM influence_contest WHERE chain_id=ch AND end_height>h ORDER BY contest_id LOOP
  PERFORM influence_rebuild(c.contest_id);
 END LOOP;
END $$;

-- Revoke default public execution. Internal projection helpers are available
-- only to the indexer, while contest administration/recovery is operator-owned.
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='structs' AND p.proname LIKE 'influence_%' LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC',f.signature);
 END LOOP;
END $$;
GRANT EXECUTE ON FUNCTION structs.influence_lock(),structs.influence_adjust(bigint,text,smallint,bigint,bigint,jsonb,text),
 structs.influence_project_member(bigint,text,text,jsonb),structs.influence_project_raid(bigint,bigint,jsonb),
 structs.influence_record_member(jsonb,text,text),structs.influence_record_raid(jsonb,jsonb),
 structs.influence_begin_block(text,bigint,text,timestamptz,boolean),structs.influence_finish_block(text,bigint,text),
 structs.influence_reconcile(bigint) TO structs_indexer;
GRANT EXECUTE ON FUNCTION structs.influence_reconcile(bigint) TO structs_webapp;
-- Source facts are append-only for the ingestion role. Recovery, configuration,
-- build publication and rollup watermarks require the migration owner.
REVOKE UPDATE,DELETE ON structs.influence_raid,structs.influence_membership_history FROM structs_indexer;
REVOKE INSERT,UPDATE,DELETE ON structs.influence_rule_set,structs.influence_contest,
 structs.influence_published_build,structs.influence_rollup_coverage,structs.influence_checkpoint FROM structs_indexer;
REVOKE INSERT,DELETE ON structs.influence_projection_build FROM structs_indexer;
COMMIT;
