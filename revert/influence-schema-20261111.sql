BEGIN;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM structs.influence_raid) OR EXISTS(SELECT 1 FROM structs.influence_contest) OR EXISTS(SELECT 1 FROM structs.influence_source_cursor)
 THEN RAISE EXCEPTION 'influence is populated; refusing destructive schema revert'; END IF; END $$;
DROP VIEW structs.influence_standings;
DROP MATERIALIZED VIEW structs.influence_score_change_1000;
DROP TABLE structs.influence_checkpoint,structs.influence_rollup_coverage,structs.influence_score_change;
DROP FUNCTION structs.influence_current_height();
DROP TABLE structs.influence_guild_sector,structs.influence_player_sector,structs.influence_planet_claim,
 structs.influence_guild_planet_win,structs.influence_player_planet_win,structs.influence_contest_planet,structs.influence_member;
DROP TABLE structs.influence_published_build,structs.influence_projection_build,structs.influence_contest,
 structs.influence_rule_set,structs.influence_raid,structs.influence_membership_history,structs.influence_source_cursor;
COMMIT;
