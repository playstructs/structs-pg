-- Run only against a disposable, fully migrated database. Every fixture rolls back.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL track_functions = 'none';
SELECT pg_advisory_xact_lock(hashtext('structs.api_work_refresh'));
SET LOCAL ROLE structs_indexer;
SELECT * FROM structs.api_work_refresh_full(100,NOW(),FALSE);
RESET ROLE;

CREATE FUNCTION pg_temp.assert_work_matches_spec() RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS ((SELECT * FROM view.work EXCEPT ALL SELECT * FROM view.work_live)
               UNION ALL (SELECT * FROM view.work_live EXCEPT ALL SELECT * FROM view.work)) THEN
        RAISE EXCEPTION 'cached work differs from live specification';
    END IF;
    IF EXISTS (SELECT FROM structs.api_work_dirty) THEN
        RAISE EXCEPTION 'refresh left dirty keys';
    END IF;
END $$;

INSERT INTO structs.struct_type(id,type,build_difficulty,ore_mining_difficulty,ore_refining_difficulty,
                                planetary_mining,planetary_refinery)
VALUES (990988,'target lookup fixture',18446744073709551615,9223372036854775808,9007199254740993,
        'oreMiningRig','oreRefinery');
INSERT INTO structs.planet(id,owner,location_list_start)
VALUES ('2-990988','1-990988','9-990988'),('2-990989','1-990989','');
INSERT INTO structs.fleet(id,owner,location_type,location_id)
VALUES ('9-990988','1-990988','planet','2-990988');
INSERT INTO structs.struct(id,index,type,owner,location_type,location_id,is_destroyed) VALUES
('5-990988',990988,990988,'1-990988','planet','2-990988',FALSE),
('5-990989',990989,990988,'1-990988','planet','2-990988',FALSE),
('5-990990',990990,990988,'1-990989','planet','2-990989',FALSE);
INSERT INTO structs.struct_attribute(id,object_id,object_type,attribute_type,val) VALUES
('1-5-990988','5-990988','struct','status',1),
('2-5-990988','5-990988','struct','blockStartBuild',18446744073709551615),
('1-5-990989','5-990989','struct','status',9223372036854775814),
('1-5-990990','5-990990','struct','status',1);
INSERT INTO structs.grid(id,object_id,object_type,attribute_type,val) VALUES
('0-2-990988','2-990988','planet','ore',1),('0-1-990988','1-990988','player','ore',1);
INSERT INTO structs.planet_attribute(id,object_id,object_type,attribute_type,val) VALUES
('0-2-990988','2-990988','planet','planetaryShield',18446744073709551615),
('10-2-990988','2-990988','planet','blockStartRaid',9223372036854775808),
('12-2-990988','2-990988','planet','blockStartOreMine',9007199254740993),
('13-2-990988','2-990988','planet','blockStartOreRefine',18446744073709551615);

-- All four categories, exact uint64 values, and actual non-superuser execution.
SET LOCAL ROLE structs_indexer;
DO $$ BEGIN
    IF (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) THEN
        RAISE EXCEPTION 'test requires a non-superuser indexer';
    END IF;
END $$;
SELECT * FROM structs.api_work_refresh(101,NOW());
RESET ROLE;
SELECT pg_temp.assert_work_matches_spec();
DO $$ BEGIN
    IF (SELECT count(*) FROM structs.api_work WHERE target_id IN ('5-990988','5-990989','5-990990','2-990988'))<>5
       OR NOT EXISTS (SELECT FROM structs.api_work WHERE target_id='5-990988'
                      AND block_start=18446744073709551615 AND difficulty_target=18446744073709551615)
    THEN RAISE EXCEPTION 'category or uint64 fixture is incomplete'; END IF;
END $$;

-- Overlapping planet/player/struct expansion must not duplicate targets.
-- Also exercise a fleet dependency (RAID player changes), clock updates,
-- BUILD -> MINE/REFINE transitions, missing-key deletion and replay no-ops.
UPDATE structs.struct_attribute SET val=6 WHERE id='1-5-990988';
UPDATE structs.planet_attribute SET val=9223372036854775808 WHERE id='12-2-990988';
UPDATE structs.fleet SET owner='1-990989' WHERE id='9-990988';
INSERT INTO structs.api_work_dirty(kind,id) VALUES ('player','1-990988'),('struct','5-990988'),('planet','2-990988') ON CONFLICT DO NOTHING;
INSERT INTO structs.api_work(object_id,player_id,target_id,category,block_start,difficulty_target,source_height)
VALUES ('5-999998','1-990988','5-999998','BUILD',0,1,101);
INSERT INTO structs.api_work_dirty(kind,id) VALUES ('struct','5-999998');
SET LOCAL ROLE structs_indexer;
SELECT * FROM structs.api_work_refresh(102,NOW());
RESET ROLE;
SELECT pg_temp.assert_work_matches_spec();
DO $$ BEGIN
    IF (SELECT source_height FROM structs.api_work WHERE target_id='5-990990')<>101 THEN
        RAISE EXCEPTION 'unrelated target was rewritten';
    END IF;
    IF (SELECT source_height FROM structs.api_refresh_state WHERE model='work')<>102 THEN
        RAISE EXCEPTION 'work watermark not advanced';
    END IF;
END $$;
INSERT INTO structs.api_work_dirty(kind,id) VALUES ('player','1-990988'),('planet','2-990988'),('fleet','9-990988');
SET LOCAL ROLE structs_indexer;
DO $$ DECLARE r RECORD; BEGIN
    SELECT * INTO r FROM structs.api_work_refresh(103,NOW());
    IF (r.inserted,r.updated,r.deleted)<>(0,0,0) THEN RAISE EXCEPTION 'replay rewrote unchanged work: %',r; END IF;
    SELECT * INTO r FROM structs.api_work_refresh(104,NOW());
    IF (r.inserted,r.updated,r.deleted)<>(0,0,0) THEN RAISE EXCEPTION 'empty queue changed work: %',r; END IF;
    IF (SELECT source_height FROM structs.api_refresh_state WHERE model='work')<>104 THEN
        RAISE EXCEPTION 'empty refresh did not advance watermark';
    END IF;
END $$;
RESET ROLE;

-- A burst expands shared ownership/location keys alongside direct keys.
INSERT INTO structs.struct(id,index,type,owner,location_type,location_id,is_destroyed)
SELECT '5-'||i,i,990988,'1-990988','planet','2-990988',FALSE FROM generate_series(991000,991499)i;
INSERT INTO structs.struct_attribute(id,object_id,object_type,attribute_type,val)
SELECT '1-5-'||i,'5-'||i,'struct','status',1 FROM generate_series(991000,991499)i;
INSERT INTO structs.api_work_dirty(kind,id) VALUES ('planet','2-990988'),('player','1-990988') ON CONFLICT DO NOTHING;
SET LOCAL plan_cache_mode=force_generic_plan;
SET LOCAL ROLE structs_indexer;
SELECT * FROM structs.api_work_refresh(105,NOW());
RESET ROLE;
SELECT pg_temp.assert_work_matches_spec();
SET LOCAL plan_cache_mode=force_custom_plan;
UPDATE structs.struct SET is_destroyed=TRUE WHERE id BETWEEN '5-991000' AND '5-991499';
SET LOCAL ROLE structs_indexer;
SELECT * FROM structs.api_work_refresh(106,NOW());
RESET ROLE;
SELECT pg_temp.assert_work_matches_spec();

-- Eligibility loss removes MINE/REFINE and RAID rows.
UPDATE structs.grid SET val=0 WHERE id IN ('0-1-990988','0-2-990988');
UPDATE structs.planet SET location_list_start='' WHERE id='2-990988';
SET LOCAL ROLE structs_indexer;
SELECT * FROM structs.api_work_refresh(107,NOW());
RESET ROLE;
SELECT pg_temp.assert_work_matches_spec();

-- Exactly 2000 keys remains incremental: an unrelated stale row is retained.
-- 2001 switches to the existing full repair and removes that stale row.
INSERT INTO structs.api_work(object_id,player_id,target_id,category,block_start,difficulty_target,source_height)
VALUES ('5-999997','1-990988','5-999997','BUILD',0,1,107);
INSERT INTO structs.api_work_dirty(kind,id) SELECT 'struct','5-'||i FROM generate_series(992000,993999)i;
SET LOCAL ROLE structs_indexer;
SELECT * FROM structs.api_work_refresh(108,NOW());
RESET ROLE;
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM structs.api_work WHERE target_id='5-999997') THEN
        RAISE EXCEPTION '2000-key call unexpectedly refreshed unrelated work';
    END IF;
END $$;
INSERT INTO structs.api_work_dirty(kind,id) SELECT 'struct','5-'||i FROM generate_series(992000,994000)i;
SET LOCAL ROLE structs_indexer;
SELECT * FROM structs.api_work_refresh(109,NOW());
RESET ROLE;
SELECT pg_temp.assert_work_matches_spec();
ROLLBACK;
