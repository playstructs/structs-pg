-- Run against a Sqitch-deployed disposable database. Every fixture rolls back.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO sync_state.sync_cursor(chain_id,last_height,last_block_time)
VALUES ('native-snapshot-sql',200,'2026-10-29T12:00:00Z');
SET LOCAL ROLE structs_indexer;
DO $$
DECLARE bad TEXT;
BEGIN
    IF (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) THEN
        RAISE EXCEPTION 'this fixture requires a non-superuser indexer';
    END IF;
    INSERT INTO sync_state.native_staking_snapshot(chain_id,address,required_height)
    VALUES ('native-snapshot-sql','structs1fixture',100);
    IF NOT EXISTS (SELECT 1 FROM sync_state.native_staking_claim
        WHERE chain_id='native-snapshot-sql' AND NOT complete AND bonded IS NULL AND unbonding IS NULL) THEN
        RAISE EXCEPTION 'an unfetched address must be unknown';
    END IF;
    UPDATE sync_state.native_staking_snapshot
    SET source_height=100,bonded=18446744073709551616,unbonding=340,fetched_at=NOW()
    WHERE chain_id='native-snapshot-sql';
    IF NOT EXISTS (SELECT 1 FROM sync_state.native_staking_claim
        WHERE chain_id='native-snapshot-sql' AND complete AND bonded=18446744073709551616 AND unbonding=340) THEN
        RAISE EXCEPTION 'exact current evidence was lost';
    END IF;
    FOREACH bad IN ARRAY ARRAY['-1','1.1','NaN','Infinity','-Infinity'] LOOP
        BEGIN
            UPDATE sync_state.native_staking_snapshot SET bonded=bad::numeric WHERE chain_id='native-snapshot-sql';
            RAISE EXCEPTION 'invalid bonded value accepted: %',bad;
        EXCEPTION WHEN check_violation THEN NULL;
        END;
    END LOOP;
    BEGIN
        UPDATE sync_state.native_staking_snapshot SET unbonding=NULL WHERE chain_id='native-snapshot-sql';
        RAISE EXCEPTION 'partial evidence accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    INSERT INTO sync_state.native_staking_exposure(chain_id,validator,address)
    VALUES ('native-snapshot-sql','structsvaloper1fixture','structs1fixture');
    INSERT INTO sync_state.native_staking_invalidation(chain_id,validator,height)
    VALUES ('native-snapshot-sql','structsvaloper1fixture',101),('native-snapshot-sql','',102);
    IF (SELECT MAX(height) FROM sync_state.native_staking_invalidation WHERE chain_id='native-snapshot-sql') <> 102 THEN
        RAISE EXCEPTION 'indexer cannot maintain invalidation watermarks';
    END IF;
    UPDATE sync_state.native_staking_snapshot SET required_height=101 WHERE chain_id='native-snapshot-sql';
    IF NOT EXISTS (SELECT 1 FROM sync_state.native_staking_claim
        WHERE chain_id='native-snapshot-sql' AND NOT complete AND bonded IS NULL AND unbonding IS NULL) THEN
        RAISE EXCEPTION 'old evidence remained current after invalidation';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM sync_state.native_staking_snapshot
        WHERE chain_id='native-snapshot-sql' AND pending AND bonded=18446744073709551616) THEN
        RAISE EXCEPTION 'invalidation must retain old evidence without publishing it';
    END IF;
    DELETE FROM sync_state.native_staking_snapshot WHERE chain_id='native-snapshot-sql';
    IF EXISTS (SELECT 1 FROM sync_state.native_staking_exposure WHERE chain_id='native-snapshot-sql') THEN
        RAISE EXCEPTION 'orphaned validator exposure';
    END IF;
    DELETE FROM sync_state.native_staking_invalidation WHERE chain_id='native-snapshot-sql';
END $$;
ROLLBACK;
