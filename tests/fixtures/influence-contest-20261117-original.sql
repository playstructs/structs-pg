-- Historical deployment fixture from c2cca34, before rehearsal retirement.
-- Deploy structs-pg:influence-contest-20261117 to pg
-- Network-wide identity and bounds; never derive these from a guild's cursor.
-- H=3633445 at 2026-11-17T15:19:03.382818Z; preceding 5000 blocks:
-- 5.3083316126 seconds/block. Estimated Toronto time: Nov 17 10:27:33
-- through Nov 18 10:27:31, inclusive. See docs/influence-contest-20261117.md.
BEGIN;
SELECT structs.influence_lock();

DO $$
DECLARE next_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM structs.influence_rule_set WHERE rule_id=1
  AND win_points=100 AND claim_points=200
  AND policy='{"uniqueness":"planet_per_guild","completed_planets":"retain","eligibility":"cross_guild_at_event","ineligible_success":"clear_claim"}'::jsonb) THEN
  RAISE EXCEPTION 'contest 2 requires the unchanged 100/200 planet-per-guild rule 1';
 END IF;
 IF EXISTS(SELECT 1 FROM structs.influence_contest WHERE contest_id=2
  AND (chain_id,start_height,end_height,rule_id,scoring_mode)
   IS DISTINCT FROM ('structstestnet-111'::text,3633541::bigint,3649817::bigint,1::bigint,'planet_sectors'::text)) THEN
  RAISE EXCEPTION 'contest ID 2 is already used by a different contest; resolve the conflict before deploying';
 END IF;
 IF EXISTS(SELECT 1 FROM structs.influence_contest WHERE chain_id='structstestnet-111'
  AND start_height=3633541 AND end_height=3649817 AND contest_id<>2) THEN
  RAISE EXCEPTION 'the November 17 contest already exists under a different ID';
 END IF;
 INSERT INTO structs.influence_contest(contest_id,chain_id,start_height,end_height,rule_id,scoring_mode)
 VALUES(2,'structstestnet-111',3633541,3649817,1,'planet_sectors')
 ON CONFLICT(contest_id) DO NOTHING;
 -- Explicit identity must also be safe on guilds that never installed contest 1.
 -- ALTER SEQUENCE is transactional; do not rewind an already advanced sequence.
 SELECT greatest((SELECT max(contest_id)+1 FROM structs.influence_contest),
  last_value+CASE WHEN is_called THEN 1 ELSE 0 END) INTO next_id
 FROM structs.influence_contest_contest_id_seq;
 EXECUTE format('ALTER SEQUENCE structs.influence_contest_contest_id_seq RESTART WITH %s',next_id);
END $$;

-- A fresh schema can precede the writer. Initialize only after its entire first
-- block/baseline commits, never inside the cursor INSERT before membership exists.
-- The function is scoped to this immutable contest and cannot be called as an RPC.
CREATE FUNCTION structs.influence_contest_20261117_initialize() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,structs,pg_temp AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM structs.influence_published_build WHERE contest_id=2) THEN RETURN NEW; END IF;
 PERFORM structs.influence_lock();
 IF EXISTS(SELECT 1 FROM structs.influence_source_cursor
   WHERE chain_id='structstestnet-111' AND coverage_start<=3633541)
  AND NOT EXISTS(SELECT 1 FROM structs.influence_published_build WHERE contest_id=2) THEN
  PERFORM structs.influence_rebuild(2);
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION structs.influence_contest_20261117_initialize() FROM PUBLIC;
CREATE CONSTRAINT TRIGGER influence_contest_20261117_initialize
 AFTER INSERT OR UPDATE ON structs.influence_source_cursor
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
 WHEN(NEW.chain_id='structstestnet-111' AND NEW.coverage_start<=3633541)
 EXECUTE FUNCTION structs.influence_contest_20261117_initialize();

DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM structs.influence_source_cursor
  WHERE chain_id='structstestnet-111' AND coverage_start<=3633541) THEN
  IF NOT EXISTS(SELECT 1 FROM structs.influence_published_build WHERE contest_id=2) THEN
   PERFORM structs.influence_rebuild(2);
  END IF;
 ELSE
  RAISE NOTICE 'contest 2 registered; publication requires exact structstestnet-111 influence coverage from block 3633541 or earlier';
 END IF;
END $$;
COMMIT;
