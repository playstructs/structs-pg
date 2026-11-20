-- Deploy structs-pg:influence-official-contest-20261120 to pg
-- Authorized reset of ALL rehearsal contests, not canonical chain history.
-- Official contest 1: inclusive 3743186..3957791, sectors 44/127/999.
BEGIN;
SET LOCAL lock_timeout='10s';
SELECT structs.influence_lock();
-- Drain in-flight API snapshots before replacing their contest/rollup tables.
LOCK TABLE structs.influence_contest IN ACCESS EXCLUSIVE MODE;

-- Keep only routing/predecessor metadata until zero/removal replacements are
-- queued. No test score, roster or history payload is retained in this snapshot.
CREATE TEMP TABLE influence_reset_scopes ON COMMIT DROP AS
 SELECT DISTINCT ON(subject) subject,contest_id,payload->>'chain_id' AS chain_id,
 frame_id AS previous_frame_id,
 substring(subject FROM length('structs.influence.'||(payload->>'chain_id')||'.'||contest_id||'.')+1) AS scope
 FROM structs.influence_grass_frame ORDER BY subject,frame_id DESC;
CREATE TEMP TABLE influence_reset_generation(build_id bigint) ON COMMIT DROP;

-- Do not recycle internal generations/message IDs: subscribers and running
-- relays may still remember them. Only the public contest/rule numbering resets.
DO $$
DECLARE next_build bigint; next_frame bigint;
BEGIN
 SELECT greatest(last_value+CASE WHEN is_called THEN 1 ELSE 0 END,
  coalesce((SELECT max(build_id)+1 FROM structs.influence_projection_build),1),
  coalesce((SELECT max(build_id)+1 FROM structs.influence_grass_frame),1)) INTO next_build
 FROM structs.influence_projection_build_build_id_seq;
 SELECT greatest(last_value+CASE WHEN is_called THEN 1 ELSE 0 END,
  coalesce((SELECT max(frame_id)+1 FROM structs.influence_grass_frame),1),
  coalesce((SELECT max(last_frame_id)+1 FROM structs.influence_grass_delivery),1)) INTO next_frame
 FROM structs.influence_grass_frame_frame_id_seq;
 EXECUTE format('ALTER SEQUENCE structs.influence_projection_build_build_id_seq RESTART WITH %s',next_build);
 EXECUTE format('ALTER SEQUENCE structs.influence_grass_frame_frame_id_seq RESTART WITH %s',next_frame);
 INSERT INTO pg_temp.influence_reset_generation
 VALUES(nextval('structs.influence_projection_build_build_id_seq'));
END $$;

-- New upgrades skip the retired seed; older installations may have its hook.
DROP TRIGGER IF EXISTS influence_contest_20261117_initialize ON structs.influence_source_cursor;
DROP FUNCTION IF EXISTS structs.influence_contest_20261117_initialize();

-- Explicit list: no CASCADE into canonical raid/membership/cursor tables.
-- Keep relay delivery cursors as well: their publishers hold a cursor in memory.
TRUNCATE TABLE
 structs.influence_contest,structs.influence_rule_set,
 structs.influence_published_build,structs.influence_projection_build,
 structs.influence_member,structs.influence_contest_planet,
 structs.influence_player_planet_win,structs.influence_guild_planet_win,
 structs.influence_planet_claim,structs.influence_player_sector,
 structs.influence_guild_sector,structs.influence_score_change,
 structs.influence_player_score_change,structs.influence_checkpoint,
 structs.influence_rollup_coverage,structs.influence_grass_dirty,
 structs.influence_grass_frame CONTINUE IDENTITY;

-- TRUNCATE of a Timescale source does not immediately clear its materialized
-- aggregate. Purge all materialized chunks through the supported public API,
-- retaining the view identity, grants, indexes and any operator-added policies.
DO $$
DECLARE extension_schema name;
BEGIN
 SELECT n.nspname INTO STRICT extension_schema
 FROM pg_catalog.pg_extension e JOIN pg_catalog.pg_namespace n ON n.oid=e.extnamespace
 WHERE e.extname='timescaledb';
 EXECUTE format('SELECT %I.drop_chunks($1::regclass, older_than=>$2::bigint)',extension_schema)
 USING 'structs.influence_score_change_1000',9223372036854775807::bigint;
END $$;

ALTER SEQUENCE structs.influence_rule_set_rule_id_seq RESTART WITH 1;
INSERT INTO structs.influence_rule_set(win_points,claim_points,policy)
VALUES(100,200,'{"uniqueness":"planet_per_guild","completed_planets":"retain","eligibility":"cross_guild_at_event","ineligible_success":"clear_claim"}');
ALTER SEQUENCE structs.influence_contest_contest_id_seq RESTART WITH 1;
INSERT INTO structs.influence_contest(chain_id,start_height,end_height,rule_id,scoring_mode)
VALUES('structstestnet-111',3743186,3957791,1,'planet_sectors');

-- Replace previously published test scopes with complete empty state. These
-- fresh control messages contain no test scores, rosters, bounds or rules.
-- Existing clients can clear their local data without an HTTP refresh. The
-- official build subsequently replaces contest 1 with its full real definition.
WITH scopes AS (
 SELECT s.*,g.build_id,coalesce(c.height,0) AS height,
 split_part(s.scope,'.',1) AS kind,split_part(s.scope,'.',2) AS entity,
 jsonb_build_object('contest_id',s.contest_id::text,'chain_id',s.chain_id,
  'build_id',g.build_id::text,'projected_height',coalesce(c.height,0)::text,
  'state','invalid','status','removed','exists',false,'data_ready',false,
  'replacement_contest_id','1','replacement_chain_id','structstestnet-111') AS ctx,
 jsonb_build_object('start_height','1','end_height',coalesce(c.height,0)::text,
  'opening_height','0','opening_is_zero',true,'complete',true,'samples','[]'::jsonb) AS history
 FROM pg_temp.influence_reset_scopes s CROSS JOIN pg_temp.influence_reset_generation g
 LEFT JOIN structs.influence_source_cursor c ON c.chain_id=s.chain_id
), frames AS (
 SELECT *,nextval('structs.influence_grass_frame_frame_id_seq') AS id,
 CASE kind
  WHEN 'contest' THEN ctx
  WHEN 'scores' THEN jsonb_build_object('exists',false,'standings','[]'::jsonb,'history',history)
  WHEN 'guild' THEN jsonb_build_object('exists',false,'guild_id',entity,'sectors','[]'::jsonb,
   'reset_roster',true,'players','[]'::jsonb,'history',history)
  WHEN 'player' THEN jsonb_build_object('exists',false,'player_id',entity,'guild_id',NULL,
   'previous_guild_id',NULL,'sectors','[]'::jsonb,'unique_planets','0','held_planets','0','points','0',
   'overall_points','0','score_kind','personal','additive_to_guild',false,'history',history)
  WHEN 'planet' THEN jsonb_build_object('exists',false,'planet_id',entity,'sector',NULL,
   'holder',NULL,'holder_guild_id',NULL,'latest_raid',NULL,'guild_coverage','[]'::jsonb)
 END AS data
 FROM scopes ORDER BY subject
)
INSERT INTO structs.influence_grass_frame(frame_id,contest_id,build_id,height,subject,payload)
OVERRIDING SYSTEM VALUE
SELECT id,contest_id,build_id,height,subject,
 jsonb_build_object('contract','structs-influence-grass-v1','subject',subject,
  'category','influence_'||kind,'frame_id',id::text,'previous_frame_id',previous_frame_id::text,
  'mode','replace','contest_id',contest_id::text,'chain_id',chain_id,'build_id',build_id::text,
  'height',height::text,'block_hash',NULL,'block_time',NULL,'context',ctx,'data',data)
FROM frames;
SELECT pg_notify('influence_grass','ready');

-- Fresh installs can deploy the definition before the writer has bootstrapped.
-- Deferral ensures baseline membership and all first-block events are present.
CREATE FUNCTION structs.influence_official_contest_initialize() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,structs,pg_temp AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM structs.influence_published_build WHERE contest_id=1) THEN RETURN NEW; END IF;
 PERFORM structs.influence_lock();
 IF EXISTS(SELECT 1 FROM structs.influence_source_cursor
  WHERE chain_id='structstestnet-111' AND coverage_start<=3743186)
  AND NOT EXISTS(SELECT 1 FROM structs.influence_published_build WHERE contest_id=1) THEN
  PERFORM structs.influence_rebuild(1);
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION structs.influence_official_contest_initialize() FROM PUBLIC;
CREATE CONSTRAINT TRIGGER influence_official_contest_initialize
 AFTER INSERT OR UPDATE ON structs.influence_source_cursor
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
 WHEN(NEW.chain_id='structstestnet-111' AND NEW.coverage_start<=3743186)
 EXECUTE FUNCTION structs.influence_official_contest_initialize();

DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM structs.influence_source_cursor
  WHERE chain_id='structstestnet-111' AND coverage_start<=3743186) THEN
  PERFORM structs.influence_rebuild(1);
 ELSE
  RAISE NOTICE 'official contest 1 registered; publication requires exact structstestnet-111 influence coverage from block 3743186 or earlier';
 END IF;
END $$;
COMMIT;
