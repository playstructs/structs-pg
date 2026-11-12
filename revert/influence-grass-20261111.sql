BEGIN;
SELECT structs.influence_lock();
DO $$ BEGIN IF EXISTS(SELECT 1 FROM structs.influence_grass_frame) THEN
 RAISE EXCEPTION 'influence grass outbox is populated; preserve pending delivery data before rollback'; END IF; END $$;
DROP TRIGGER influence_grass_published ON structs.influence_published_build;
DROP FUNCTION structs.influence_grass_published();
DROP FUNCTION structs.influence_project_raid(bigint,bigint,jsonb),structs.influence_project_member(bigint,text,text,jsonb);
ALTER FUNCTION structs.influence_project_raid_without_grass(bigint,bigint,jsonb) RENAME TO influence_project_raid;
ALTER FUNCTION structs.influence_project_member_without_grass(bigint,text,text,jsonb) RENAME TO influence_project_member;
DROP FUNCTION structs.influence_grass_emit_history(bigint,text,text,text);
DROP FUNCTION structs.influence_grass_flush(text,bigint,text,timestamptz),structs.influence_grass_emit(bigint,boolean,text,timestamptz),
 structs.influence_grass_put(bigint,text,text,text,jsonb,text,timestamptz),structs.influence_grass_history(bigint,text,text,bigint,bigint),
 structs.influence_grass_planet(bigint,text),structs.influence_grass_player(bigint,text),structs.influence_grass_scores(bigint),
 structs.influence_grass_context(bigint),structs.influence_grass_sectors(bigint),structs.influence_grass_mark(bigint,text,text),
 structs.influence_grass_personal_delta(bigint,bigint,text,smallint,bigint,bigint);
DROP TABLE structs.influence_grass_delivery,structs.influence_grass_frame,structs.influence_grass_dirty,structs.influence_player_score_change;
COMMIT;
