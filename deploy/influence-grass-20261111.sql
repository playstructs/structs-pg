-- Deploy structs-pg:influence-grass-20261111 to pg
BEGIN;
SET LOCAL search_path=structs,public,pg_temp;
SELECT influence_lock();

-- Personal history is distinct from the guild union ledger. Coalesce changes
-- within a block; keep zero rows so multiple successes have deterministic output.
CREATE TABLE influence_player_score_change (
 build_id bigint NOT NULL REFERENCES influence_projection_build ON DELETE CASCADE,
 height bigint NOT NULL CHECK(height>0), player text NOT NULL, sector smallint NOT NULL CHECK(sector IN (0,44,127,999)),
 unique_delta bigint NOT NULL, claim_delta bigint NOT NULL,
 PRIMARY KEY(build_id,height,player,sector)
);
SELECT create_hypertable('influence_player_score_change',by_range('height',100000::bigint),create_default_indexes=>false);
CREATE INDEX influence_player_score_change_subject ON influence_player_score_change(build_id,player,height,sector);
CREATE TABLE influence_grass_dirty (
 build_id bigint NOT NULL REFERENCES influence_projection_build ON DELETE CASCADE,
 kind text NOT NULL CHECK(kind IN ('player','planet')), entity text NOT NULL,
 opening_guild text, PRIMARY KEY(build_id,kind,entity)
);
-- Intentionally no FK to projections: pending delivery must survive a rewind.
-- The single influence writer lock serializes IDs with commit order.
CREATE TABLE influence_grass_frame (
 frame_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 contest_id bigint NOT NULL, build_id bigint NOT NULL, height bigint NOT NULL,
 subject text NOT NULL, payload jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX influence_grass_frame_subject ON influence_grass_frame(subject,frame_id);
CREATE INDEX influence_grass_frame_contest ON influence_grass_frame(contest_id,frame_id);
CREATE INDEX influence_grass_frame_build_height ON influence_grass_frame(build_id,height);
CREATE TABLE influence_grass_delivery (
 destination text PRIMARY KEY, last_frame_id bigint NOT NULL DEFAULT 0 CHECK(last_frame_id>=0)
);
COMMENT ON TABLE influence_grass_frame IS 'Durable full influence envelopes for relay retries. Preserve pending frames; no automatic retention job is configured.';

CREATE FUNCTION influence_grass_sectors(b bigint) RETURNS smallint[]
LANGUAGE sql STABLE SET search_path=structs,pg_temp AS $$
 SELECT CASE WHEN scoring_mode='single_sector' THEN ARRAY[0]::smallint[]
 WHEN EXISTS(SELECT 1 FROM influence_contest_planet WHERE build_id=b AND sector=0) THEN ARRAY[0,44,127,999]::smallint[]
 ELSE ARRAY[44,127,999]::smallint[] END
 FROM influence_projection_build JOIN influence_contest USING(contest_id) WHERE build_id=b
$$;
CREATE FUNCTION influence_grass_context(b bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=structs,pg_temp AS $$
 SELECT jsonb_build_object('contest_id',c.contest_id::text,'chain_id',c.chain_id,'build_id',b::text,
 'start_height',c.start_height::text,'end_height',c.end_height::text,'rule_id',c.rule_id::text,
 'win_points',r.win_points::text,'claim_points',r.claim_points::text,'policy',r.policy,
 'scoring_mode',c.scoring_mode,'sectors',influence_grass_sectors(b),'state',x.state,
 'projected_height',x.projected_height::text,'source_height',cur.height::text,'coverage_start',cur.coverage_start::text,
 'data_ready',x.state IN ('live','final'),'sectors_complete',complete,
 'status',CASE WHEN x.state='final' THEN 'final' WHEN x.projected_height<c.start_height THEN 'scheduled'
 WHEN x.projected_height>=c.end_height AND NOT complete THEN 'awaiting_sectors' ELSE 'active' END)
 FROM influence_projection_build x JOIN influence_contest c USING(contest_id)
 JOIN influence_rule_set r USING(rule_id) JOIN influence_source_cursor cur ON cur.chain_id=c.chain_id
 CROSS JOIN LATERAL(SELECT c.scoring_mode='single_sector' OR NOT EXISTS(
 SELECT 1 FROM influence_contest_planet WHERE build_id=b AND sector=0) AS complete) ready WHERE x.build_id=b
$$;
CREATE FUNCTION influence_grass_scores(b bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=structs,pg_temp AS $$
 WITH roster AS (SELECT guild FROM influence_member WHERE build_id=b AND guild IS NOT NULL
 UNION SELECT guild FROM influence_guild_sector WHERE build_id=b), components AS (
 SELECT roster.guild AS guild_id,sec.sector,coalesce(s.unique_planets,0) u,coalesce(s.held_planets,0) c,
 coalesce(s.unique_planets,0)::numeric*r.win_points+coalesce(s.held_planets,0)::numeric*r.claim_points points
 FROM roster CROSS JOIN unnest(influence_grass_sectors(b)) sec(sector)
 CROSS JOIN influence_projection_build x JOIN influence_contest ct USING(contest_id) JOIN influence_rule_set r USING(rule_id)
 LEFT JOIN influence_guild_sector s ON s.build_id=b AND s.guild=roster.guild AND s.sector=sec.sector
 WHERE x.build_id=b
 ), totals AS(SELECT *,sum(points) OVER(PARTITION BY guild_id) overall_points FROM components),
 ranked AS(SELECT *,dense_rank() OVER(PARTITION BY sector ORDER BY points DESC,overall_points DESC) rank FROM totals),
 rows AS(SELECT guild_id,sector,u::text unique_planets,c::text held_planets,points::text,overall_points::text,rank::text sector_rank,
 points>0 AND rank=1 AND count(*) FILTER(WHERE rank=1) OVER(PARTITION BY sector)>1 tied_for_lead,
 points>0 AND rank=1 AND (influence_grass_context(b)->>'status')='final' is_winner FROM ranked)
 SELECT coalesce(jsonb_agg(to_jsonb(rows) ORDER BY sector,sector_rank::bigint,guild_id),'[]') FROM rows
$$;

CREATE FUNCTION influence_grass_player(b bigint,who text) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=structs,pg_temp AS $$
 WITH wins AS(SELECT cp.sector,count(*) n FROM influence_player_planet_win w
 JOIN influence_contest_planet cp USING(build_id,planet) WHERE w.build_id=b AND player=who GROUP BY cp.sector),
 rows AS(SELECT sec.sector,coalesce(w.n,0)::text unique_planets,coalesce(s.held_planets,0)::text held_planets,
 (coalesce(w.n,0)::numeric*r.win_points+coalesce(s.held_planets,0)::numeric*r.claim_points)::text points
 FROM unnest(influence_grass_sectors(b)) sec(sector)
 JOIN influence_projection_build x ON x.build_id=b JOIN influence_contest c USING(contest_id) JOIN influence_rule_set r USING(rule_id)
 LEFT JOIN wins w USING(sector) LEFT JOIN influence_player_sector s ON s.build_id=b AND s.player=who AND s.sector=sec.sector)
 SELECT jsonb_build_object('player_id',who,'guild_id',(SELECT guild FROM influence_member WHERE build_id=b AND player=who),
 'exists',EXISTS(SELECT 1 FROM influence_member WHERE build_id=b AND player=who),'score_kind','personal','additive_to_guild',false,
 'unique_planets',sum(unique_planets::numeric)::text,'held_planets',sum(held_planets::numeric)::text,'points',sum(points::numeric)::text,
 'overall_points',sum(points::numeric)::text,'sectors',jsonb_agg(to_jsonb(rows) ORDER BY sector)) FROM rows
$$;
CREATE FUNCTION influence_grass_planet(b bigint,who text) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=structs,pg_temp AS $$
 SELECT jsonb_build_object('planet_id',who,'exists',c.planet IS NOT NULL,'sector',c.sector,'holder',c.holder,
 'holder_guild_id',m.guild,'latest_raid',CASE WHEN r.raid_id IS NULL THEN NULL ELSE jsonb_build_object(
 'raid_id',r.raid_id::text,'height',r.height::text,'attacker',r.attacker,'defender',r.defender,
 'attacker_guild',r.attacker_guild,'defender_guild',r.defender_guild,'source_sector',r.sector) END,
 'guild_coverage',coalesce((SELECT jsonb_agg(jsonb_build_object('guild_id',guild,'supporter_count',supporter_count::text) ORDER BY guild)
 FROM influence_guild_planet_win WHERE build_id=b AND planet=who),'[]'))
 FROM (SELECT 1) seed LEFT JOIN influence_planet_claim c ON c.build_id=b AND c.planet=who
 LEFT JOIN influence_member m ON m.build_id=b AND m.player=c.holder LEFT JOIN influence_raid r ON r.raid_id=c.latest_raid_id
$$;
-- Sparse deltas plus a zero opening baseline exactly reconstruct arbitrary
-- buckets. A replace frame replaces the entire [start,end] history, even empty.
CREATE FUNCTION influence_grass_history(b bigint,kind text,who text,lo bigint,hi bigint) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=structs,pg_temp AS $$
 WITH d AS (
 SELECT height,guild entity,sector,sum(unique_delta) u,sum(claim_delta) c FROM influence_score_change
 WHERE build_id=b AND kind='guild' AND (who IS NULL OR guild=who) AND height BETWEEN lo AND hi GROUP BY height,guild,sector
 UNION ALL
 SELECT height,player,sector,unique_delta,claim_delta FROM influence_player_score_change
 WHERE build_id=b AND kind='player' AND player=who AND height BETWEEN lo AND hi
 ), rows AS(SELECT height::text,entity,sector,u::text unique_delta,c::text claim_delta,
 (u*r.win_points+c*r.claim_points)::text points_delta FROM d
 JOIN influence_projection_build x ON x.build_id=b JOIN influence_contest ct USING(contest_id) JOIN influence_rule_set r USING(rule_id)
 WHERE u<>0 OR c<>0)
 SELECT coalesce(jsonb_agg(to_jsonb(rows) ORDER BY height::bigint,entity,sector),'[]') FROM rows
$$;

CREATE FUNCTION influence_grass_put(b bigint,scope text,category text,mode text,data jsonb,hash text,t timestamptz)
RETURNS bigint LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE ctx jsonb; subj text; id bigint; prev bigint;
BEGIN
 PERFORM influence_lock();
 ctx:=influence_grass_context(b);
 subj:='structs.influence.'||(ctx->>'chain_id')||'.'||(ctx->>'contest_id')||'.'||scope;
 IF subj !~ '^[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)+$' THEN RAISE EXCEPTION 'invalid influence subject'; END IF;
 SELECT frame_id INTO prev FROM influence_grass_frame WHERE subject=subj ORDER BY frame_id DESC LIMIT 1;
 id:=nextval(pg_get_serial_sequence('structs.influence_grass_frame','frame_id'));
 INSERT INTO influence_grass_frame(frame_id,contest_id,build_id,height,subject,payload) OVERRIDING SYSTEM VALUE
 VALUES(id,(ctx->>'contest_id')::bigint,b,(ctx->>'projected_height')::bigint,subj,
 jsonb_build_object('contract','structs-influence-grass-v1','subject',subj,
 'category',category,'frame_id',id::text,'previous_frame_id',coalesce(prev,0)::text,'mode',mode,
 'contest_id',ctx->>'contest_id','chain_id',ctx->>'chain_id','build_id',b::text,'height',ctx->>'projected_height',
 'block_hash',hash,'block_time',t,'context',ctx,'data',data));
 -- Wakeup only: complete bytes are read by the relay, never by an HTTP client.
 PERFORM pg_notify('influence_grass','ready');
 RETURN id;
END $$;
CREATE FUNCTION influence_grass_mark(b bigint,kind text,who text) RETURNS void
LANGUAGE sql SET search_path=structs,pg_temp AS $$
 INSERT INTO influence_grass_dirty SELECT b,kind,who,m.guild FROM (SELECT 1) seed
 LEFT JOIN influence_member m ON m.build_id=b AND m.player=who WHERE who IS NOT NULL
 ON CONFLICT DO NOTHING
$$;
CREATE FUNCTION influence_grass_personal_delta(b bigint,h bigint,who text,s smallint,u bigint,c bigint) RETURNS void
LANGUAGE sql SET search_path=structs,pg_temp AS $$
 INSERT INTO influence_player_score_change SELECT b,h,who,s,u,c WHERE who IS NOT NULL AND (u<>0 OR c<>0)
 ON CONFLICT(build_id,height,player,sector) DO UPDATE
 SET unique_delta=influence_player_score_change.unique_delta+EXCLUDED.unique_delta,
 claim_delta=influence_player_score_change.claim_delta+EXCLUDED.claim_delta
$$;
ALTER FUNCTION influence_project_raid(bigint,bigint,jsonb) RENAME TO influence_project_raid_without_grass;
CREATE FUNCTION influence_project_raid(b bigint,rid bigint,p jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE r influence_raid%ROWTYPE; old_holder text; new_holder text; s smallint; won boolean;
BEGIN
 SELECT * INTO STRICT r FROM influence_raid WHERE raid_id=rid;
 SELECT holder INTO old_holder FROM influence_planet_claim WHERE build_id=b AND planet=r.planet;
 won:=EXISTS(SELECT 1 FROM influence_player_planet_win WHERE build_id=b AND player=r.attacker AND planet=r.planet);
 PERFORM influence_grass_mark(b,'player',r.attacker);
 PERFORM influence_grass_mark(b,'player',old_holder);
 PERFORM influence_grass_mark(b,'planet',r.planet);
 PERFORM influence_project_raid_without_grass(b,rid,p);
 SELECT holder,sector INTO new_holder,s FROM influence_planet_claim WHERE build_id=b AND planet=r.planet;
 IF NOT won AND EXISTS(SELECT 1 FROM influence_player_planet_win WHERE build_id=b AND player=r.attacker AND planet=r.planet) THEN
  PERFORM influence_grass_personal_delta(b,r.height,r.attacker,s,1,0);
 END IF;
 IF old_holder IS DISTINCT FROM new_holder THEN
  PERFORM influence_grass_personal_delta(b,r.height,old_holder,s,0,-1);
  PERFORM influence_grass_personal_delta(b,r.height,new_holder,s,0,1);
 END IF;
END $$;
ALTER FUNCTION influence_project_member(bigint,text,text,jsonb) RENAME TO influence_project_member_without_grass;
CREATE FUNCTION influence_project_member(b bigint,who text,new_guild text,p jsonb) RETURNS void
LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM influence_member WHERE build_id=b AND player=who AND guild IS NOT DISTINCT FROM nullif(new_guild,'')) THEN
  PERFORM influence_grass_mark(b,'player',who);
  INSERT INTO influence_grass_dirty(build_id,kind,entity)
  SELECT b,'planet',planet FROM influence_player_planet_win WHERE build_id=b AND player=who ON CONFLICT DO NOTHING;
 END IF;
 PERFORM influence_project_member_without_grass(b,who,new_guild,p);
END $$;

-- Backfill personal history for already-published builds from canonical facts.
WITH events AS (
 SELECT w.build_id,w.planet,p.sector,r.height,r.phase,r.tx_index,r.event_index,r.attribute_index,
 CASE WHEN r.attacker<>r.defender AND r.attacker_guild IS NOT NULL AND r.defender_guild IS NOT NULL
 AND r.attacker_guild<>r.defender_guild THEN r.attacker END holder
 FROM influence_contest_planet w JOIN influence_projection_build b USING(build_id) JOIN influence_contest c USING(contest_id)
 JOIN influence_contest_planet p USING(build_id,planet)
 JOIN influence_raid r ON r.chain_id=b.chain_id AND r.planet=w.planet AND r.height BETWEEN c.start_height AND b.projected_height
), transitions AS(SELECT *,lag(holder) OVER(PARTITION BY build_id,planet ORDER BY height,phase,tx_index,event_index,attribute_index) old_holder FROM events),
changes AS (
 SELECT w.build_id,r.height,w.player,p.sector,1::bigint u,0::bigint c FROM influence_player_planet_win w
 JOIN influence_raid r ON r.raid_id=w.first_raid_id JOIN influence_contest_planet p ON p.build_id=w.build_id AND p.planet=w.planet
 UNION ALL SELECT build_id,height,holder,sector,0,1 FROM transitions WHERE holder IS NOT NULL AND holder IS DISTINCT FROM old_holder
 UNION ALL SELECT build_id,height,old_holder,sector,0,-1 FROM transitions WHERE old_holder IS NOT NULL AND holder IS DISTINCT FROM old_holder
)
INSERT INTO influence_player_score_change SELECT build_id,height,player,sector,sum(u),sum(c) FROM changes GROUP BY build_id,height,player,sector;

-- Replacement history is streamed in bounded logical segments, never one giant
-- JSON aggregate. Clients stage these until complete=true; no refetch is needed.
CREATE FUNCTION influence_grass_emit_history(b bigint,scope text,kind text,who text) RETURNS void
LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE row_data record; chunk jsonb:='[]'; ctx jsonb; lo bigint; hi bigint;
BEGIN
 ctx:=influence_grass_context(b);lo:=(ctx->>'start_height')::bigint;hi:=(ctx->>'projected_height')::bigint;
 FOR row_data IN
 WITH d AS (
 SELECT height,guild entity,sector,sum(unique_delta) u,sum(claim_delta) c FROM influence_score_change
 WHERE build_id=b AND kind='guild' AND (who IS NULL OR guild=who) AND height BETWEEN lo AND hi GROUP BY height,guild,sector
 UNION ALL SELECT height,player,sector,unique_delta,claim_delta FROM influence_player_score_change
 WHERE build_id=b AND kind='player' AND player=who AND height BETWEEN lo AND hi
 ) SELECT height::text,entity,sector,u::text unique_delta,c::text claim_delta,
 (u*(ctx->>'win_points')::int+c*(ctx->>'claim_points')::int)::text points_delta FROM d
 WHERE u<>0 OR c<>0 ORDER BY height::bigint,entity,sector
 LOOP
  chunk:=chunk||jsonb_build_array(to_jsonb(row_data));
  IF jsonb_array_length(chunk)=512 THEN
   PERFORM influence_grass_put(b,scope,'influence_history','patch',jsonb_build_object('history',jsonb_build_object(
    'start_height',lo::text,'end_height',hi::text,'complete',false,'samples',chunk)),NULL,NULL);
   chunk:='[]';
  END IF;
 END LOOP;
 PERFORM influence_grass_put(b,scope,'influence_history','patch',jsonb_build_object('history',jsonb_build_object(
  'start_height',lo::text,'end_height',hi::text,'complete',true,'samples',chunk)),NULL,NULL);
END $$;

CREATE FUNCTION influence_grass_emit(b bigint,replacement boolean,hash text DEFAULT NULL,t timestamptz DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE ctx jsonb; scores jsonb; base text; mode text; lo bigint; hi bigint; d record; v jsonb; hist jsonb; g text;
BEGIN
 ctx:=influence_grass_context(b); hi:=(ctx->>'projected_height')::bigint;
 lo:=CASE WHEN replacement THEN (ctx->>'start_height')::bigint ELSE hi END;
 base:='structs.influence.'||(ctx->>'chain_id')||'.'||(ctx->>'contest_id')||'.';
 mode:=CASE WHEN replacement THEN 'replace' ELSE 'patch' END;
 scores:=influence_grass_scores(b);
 PERFORM influence_grass_put(b,'contest','influence_contest',mode,ctx,hash,t);
 hist:=jsonb_build_object('start_height',lo::text,'end_height',hi::text,'opening_height',((ctx->>'start_height')::bigint-1)::text,
 'opening_is_zero',replacement,'complete',NOT replacement,'samples',CASE WHEN replacement THEN '[]'::jsonb ELSE influence_grass_history(b,'guild',NULL,lo,hi) END);
 PERFORM influence_grass_put(b,'scores','influence_scores',mode,jsonb_build_object('standings',scores,'history',hist),hash,t);
 IF replacement THEN PERFORM influence_grass_emit_history(b,'scores','guild',NULL); END IF;
 FOR d IN
 SELECT entity,opening_guild FROM influence_grass_dirty WHERE build_id=b AND kind='player' AND NOT replacement
 UNION SELECT player,guild FROM influence_member WHERE build_id=b AND replacement
 UNION SELECT split_part(subject,'.',6),NULL FROM influence_grass_frame WHERE replacement
 AND contest_id=(ctx->>'contest_id')::bigint AND subject LIKE base||'player.%'
 AND NOT EXISTS(SELECT 1 FROM influence_member m WHERE m.build_id=b AND m.player=split_part(subject,'.',6))
 LOOP
  v:=influence_grass_player(b,d.entity)||jsonb_build_object('previous_guild_id',d.opening_guild,
  'history',hist||jsonb_build_object('samples',CASE WHEN replacement THEN '[]'::jsonb ELSE influence_grass_history(b,'player',d.entity,lo,hi) END));
  PERFORM influence_grass_put(b,'player.'||d.entity,'influence_player',mode,v,hash,t);
  IF replacement THEN PERFORM influence_grass_emit_history(b,'player.'||d.entity,'player',d.entity); END IF;
 END LOOP;
 -- Guild scopes are one atomic frame: scores, roster changes and graph deltas.
 FOR g IN SELECT DISTINCT value->>'guild_id' FROM jsonb_array_elements(scores)
 UNION SELECT opening_guild FROM influence_grass_dirty WHERE build_id=b AND kind='player' AND opening_guild IS NOT NULL
 UNION SELECT split_part(subject,'.',6) FROM influence_grass_frame WHERE replacement
 AND contest_id=(ctx->>'contest_id')::bigint AND subject LIKE base||'guild.%'
 LOOP
  SELECT coalesce(jsonb_agg(influence_grass_player(b,q.player)||jsonb_build_object('previous_guild_id',q.opening_guild) ORDER BY q.player),'[]') INTO v
  FROM (
   SELECT m.player,m.guild opening_guild FROM influence_member m WHERE replacement AND m.build_id=b AND m.guild=g
   UNION ALL
   SELECT dirty.entity,dirty.opening_guild FROM influence_grass_dirty dirty LEFT JOIN influence_member m ON m.build_id=dirty.build_id AND m.player=dirty.entity
   WHERE NOT replacement AND dirty.build_id=b AND dirty.kind='player' AND (m.guild=g OR dirty.opening_guild=g)
  ) q;
  PERFORM influence_grass_put(b,'guild.'||g,'influence_guild',mode,
  jsonb_build_object('guild_id',g,'sectors',coalesce((SELECT jsonb_agg(value) FROM jsonb_array_elements(scores) WHERE value->>'guild_id'=g),'[]'),
  'reset_roster',replacement,'players',v,
  'history',hist||jsonb_build_object('samples',CASE WHEN replacement THEN '[]'::jsonb ELSE influence_grass_history(b,'guild',g,lo,hi) END)),hash,t);
  IF replacement THEN PERFORM influence_grass_emit_history(b,'guild.'||g,'guild',g); END IF;
 END LOOP;
 FOR d IN SELECT entity FROM influence_grass_dirty WHERE build_id=b AND kind='planet' AND NOT replacement
 UNION SELECT planet FROM influence_contest_planet WHERE build_id=b AND replacement
 UNION SELECT split_part(subject,'.',6) FROM influence_grass_frame WHERE replacement
 AND contest_id=(ctx->>'contest_id')::bigint AND subject LIKE base||'planet.%'
 LOOP
  PERFORM influence_grass_put(b,'planet.'||d.entity,'influence_planet',mode,influence_grass_planet(b,d.entity),hash,t);
 END LOOP;
 DELETE FROM influence_grass_dirty WHERE build_id=b;
END $$;
CREATE FUNCTION influence_grass_flush(ch text,h bigint,hash text,t timestamptz) RETURNS void
LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
DECLARE b record;
BEGIN
 PERFORM influence_lock();
 IF NOT EXISTS(SELECT 1 FROM influence_source_cursor WHERE chain_id=ch AND height=h AND block_hash=hash) THEN
  RAISE EXCEPTION 'influence grass must follow a completed canonical block'; END IF;
 FOR b IN SELECT x.build_id,c.start_height,c.end_height FROM influence_projection_build x
 JOIN influence_published_build pub USING(build_id) JOIN influence_contest c ON c.contest_id=pub.contest_id
 WHERE x.chain_id=ch AND x.projected_height=h AND h<=c.end_height
 AND (h IN (c.start_height,c.end_height) OR EXISTS(SELECT 1 FROM influence_grass_dirty d WHERE d.build_id=x.build_id))
 LOOP
  -- Calling Finish twice must not duplicate final/boundary output.
  IF NOT EXISTS(SELECT 1 FROM influence_grass_frame WHERE build_id=b.build_id AND height=h AND payload->>'mode'='patch' AND payload->>'category'='influence_scores') THEN
   PERFORM influence_grass_emit(b.build_id,false,hash,t);
  END IF;
 END LOOP;
END $$;
CREATE FUNCTION influence_grass_published() RETURNS trigger LANGUAGE plpgsql SET search_path=structs,pg_temp AS $$
BEGIN
 IF TG_OP='INSERT' OR NEW.build_id IS DISTINCT FROM OLD.build_id THEN PERFORM influence_grass_emit(NEW.build_id,true); END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER influence_grass_published AFTER INSERT OR UPDATE ON influence_published_build
 FOR EACH ROW EXECUTE FUNCTION influence_grass_published();

-- Publish an initial baseline without rebuilding or changing contest scores.
DO $$ DECLARE b record; BEGIN FOR b IN SELECT build_id FROM influence_published_build ORDER BY contest_id LOOP
 PERFORM influence_grass_emit(b.build_id,true); END LOOP; END $$;
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='structs' AND (p.proname LIKE 'influence_grass_%' OR p.proname IN ('influence_project_raid','influence_project_member')) LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC',f.signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO structs_indexer',f.signature);
 END LOOP;
END $$;
GRANT SELECT,INSERT,UPDATE,DELETE ON influence_grass_dirty,influence_player_score_change TO structs_indexer;
GRANT SELECT,INSERT ON influence_grass_frame TO structs_indexer;
GRANT SELECT,INSERT,UPDATE ON influence_grass_delivery TO structs_indexer;
GRANT USAGE,SELECT ON SEQUENCE influence_grass_frame_frame_id_seq TO structs_indexer;
COMMIT;
