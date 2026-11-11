BEGIN;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM structs.influence_source_cursor) OR EXISTS(SELECT 1 FROM structs.influence_contest)
 THEN RAISE EXCEPTION 'influence is populated; preserve/restore its data before reverting'; END IF; END $$;
DROP TRIGGER influence_rule_immutable ON structs.influence_rule_set;
DROP TRIGGER influence_contest_immutable ON structs.influence_contest;
DROP TRIGGER influence_raid_immutable ON structs.influence_raid;
DROP TRIGGER influence_membership_immutable ON structs.influence_membership_history;
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='structs' AND p.proname LIKE 'influence_%' AND p.proname<>'influence_current_height' LOOP
 EXECUTE format('DROP FUNCTION %s',f.signature); END LOOP;
END $$;
ALTER TABLE structs.influence_raid DROP COLUMN source;
ALTER TABLE structs.influence_membership_history DROP COLUMN event_time;
COMMIT;
