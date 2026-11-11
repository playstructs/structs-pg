BEGIN;
SELECT 1/(to_regprocedure('structs.influence_current_height()') IS NOT NULL)::int;
SELECT raid_id,chain_id,height,phase,tx_index,event_index,attribute_index,attacker,defender,planet,sector FROM structs.influence_raid WHERE false;
SELECT build_id,guild,planet,supporter_count FROM structs.influence_guild_planet_win WHERE false;
SELECT * FROM structs.influence_standings WHERE false;
SELECT * FROM structs.influence_score_change_1000 WHERE false;
SELECT 1 / (count(*)=1)::int FROM timescaledb_information.hypertables WHERE hypertable_schema='structs' AND hypertable_name='influence_score_change';
SELECT 1 / (count(*)=1)::int FROM structs.influence_rule_set WHERE rule_id=1 AND win_points=100 AND claim_points=200;
ROLLBACK;
