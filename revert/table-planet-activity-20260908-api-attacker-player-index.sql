-- Revert structs-pg:table-planet-activity-20260908-api-attacker-player-index from pg

BEGIN;

    DROP INDEX IF EXISTS structs.planet_activity_attacker_player_block_time_planet_seq_idx;

COMMIT;
