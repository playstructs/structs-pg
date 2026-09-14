-- Deploy structs-pg:index-planet-activity-20260915-drop-time-idx to pg
--
-- planet_activity_time_idx (time DESC, 44 MB across chunks) is a strict
-- prefix of the unique planet_activity_time_planet_seq_uidx (time, planet_id,
-- seq); btree indexes scan in either direction, so every query it served is
-- served by the unique index. Drop it to save one index write per insert and
-- 44 MB. The two remaining low-value indexes (block_time_planet_seq_idx and
-- detail_gin) still back the current per-player feed and are dropped on the
-- phase-2 branch after the webapp repoints.

BEGIN;

    DROP INDEX IF EXISTS structs.planet_activity_time_idx;

COMMIT;
