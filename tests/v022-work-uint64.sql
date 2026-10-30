-- Disposable Sqitch database only; every fixture and projection change rolls back.
\set ON_ERROR_STOP on
BEGIN;
SELECT pg_advisory_xact_lock(hashtext('structs.api_work_refresh'));
INSERT INTO structs.struct_type(id,type,build_difficulty,ore_mining_difficulty,ore_refining_difficulty,
                                planetary_mining,planetary_refinery)
VALUES (990980,'uint64 work fixture',18446744073709551615,9223372036854775808,9007199254740993,
        'oreMiningRig','oreRefinery');
INSERT INTO structs.planet(id,owner,location_list_start) VALUES ('2-990980','1-990980','3-990980');
INSERT INTO structs.fleet(id,owner,location_type,location_id) VALUES ('3-990980','1-990981','planet','2-990980');
INSERT INTO structs.struct(id,index,type,owner,location_type,location_id,is_destroyed)
VALUES ('5-990980',990980,990980,'1-990980','planet','2-990980',FALSE);
INSERT INTO structs.grid(id,object_id,object_type,attribute_type,val)
VALUES ('0-2-990980','2-990980','planet','ore',1),('0-1-990980','1-990980','player','ore',1);
INSERT INTO structs.struct_attribute(id,object_id,object_type,attribute_type,val)
VALUES ('1-5-990980','5-990980','struct','status',1),
       ('2-5-990980','5-990980','struct','blockStartBuild',18446744073709551615);
INSERT INTO structs.planet_attribute(id,object_id,object_type,attribute_type,val)
VALUES ('0-2-990980','2-990980','planet','planetaryShield',18446744073709551615),
       ('10-2-990980','2-990980','planet','blockStartRaid',9223372036854775808),
       ('12-2-990980','2-990980','planet','blockStartOreMine',9007199254740993),
       ('13-2-990980','2-990980','planet','blockStartOreRefine',18446744073709551615);
SELECT * FROM structs.api_work_refresh_full(3353000,NOW(),FALSE);
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM view.work WHERE target_id='5-990980' AND category='BUILD'
        AND block_start=18446744073709551615 AND difficulty_target=18446744073709551615)
        OR NOT EXISTS (SELECT FROM view.work WHERE target_id='2-990980' AND category='RAID'
        AND block_start=9223372036854775808 AND difficulty_target=18446744073709551615) THEN
        RAISE EXCEPTION 'full refresh lost exact build/raid values';
    END IF;
END $$;
-- A high status bit must not hide the low built/online flags.
UPDATE structs.struct_attribute SET val=9223372036854775814 WHERE id='1-5-990980';
SELECT * FROM structs.api_work_refresh(3353001,NOW());
DO $$
BEGIN
    IF EXISTS (SELECT FROM view.work WHERE target_id='5-990980' AND category='BUILD')
        OR NOT EXISTS (SELECT FROM view.work WHERE target_id='5-990980' AND category='MINE'
            AND block_start=9007199254740993 AND difficulty_target=9223372036854775808)
        OR NOT EXISTS (SELECT FROM view.work WHERE target_id='5-990980' AND category='REFINE'
            AND block_start=18446744073709551615 AND difficulty_target=9007199254740993)
        OR NOT EXISTS (SELECT FROM view.struct WHERE struct_id='5-990980' AND is_online AND is_built)
    THEN RAISE EXCEPTION 'incremental work/status refresh lost exact values'; END IF;
    IF EXISTS ((SELECT * FROM view.work EXCEPT SELECT * FROM view.work_live)
               UNION ALL (SELECT * FROM view.work_live EXCEPT SELECT * FROM view.work)) THEN
        RAISE EXCEPTION 'incremental and full live projections disagree';
    END IF;
END $$;
-- All low bits of MaxUint64 are set. Ordinary NUMERIC division rounds here,
-- so this tests integer division rather than only small status bitfields.
UPDATE structs.struct_attribute SET val=18446744073709551615 WHERE id='1-5-990980';
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM view.struct_status WHERE struct_id='5-990980'
        AND materialized AND built AND online AND stored AND hidden AND destroyed AND locked) THEN
        RAISE EXCEPTION 'status bit decoding rounded a uint64';
    END IF;
END $$;
DO $$
DECLARE spec RECORD; invalid TEXT; rejected BOOLEAN;
BEGIN
    FOR spec IN SELECT * FROM (VALUES
        ('struct_attribute','val','id=''2-5-990980'''),
        ('planet_attribute','val','id=''0-2-990980'''),
        ('struct_type','build_difficulty','id=990980'),
        ('struct_type','ore_mining_difficulty','id=990980'),
        ('struct_type','ore_refining_difficulty','id=990980'),
        ('api_work','block_start','target_id=''2-990980'''),
        ('api_work','difficulty_target','target_id=''2-990980''')
    ) required(rel,col,predicate) LOOP
        FOREACH invalid IN ARRAY ARRAY['-1','0.5','18446744073709551616','NaN','Infinity','-Infinity'] LOOP
            rejected := FALSE;
            BEGIN
                EXECUTE format('UPDATE structs.%I SET %I=%L::numeric WHERE %s',
                    spec.rel,spec.col,invalid,spec.predicate);
            EXCEPTION WHEN check_violation THEN rejected := TRUE;
            END;
            IF NOT rejected THEN RAISE EXCEPTION 'accepted invalid %.% = %',spec.rel,spec.col,invalid; END IF;
        END LOOP;
    END LOOP;
END $$;
SET LOCAL ROLE structs_webapp;
SELECT block_start::text,difficulty_target::text FROM view.work WHERE target_id='2-990980';
RESET ROLE;
ROLLBACK;
