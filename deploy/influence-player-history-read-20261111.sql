-- Deploy structs-pg:influence-player-history-read-20261111 to pg
BEGIN;
-- The webapp's personal history API reads the maintained per-player deltas
-- instead of replaying raid facts with its own copy of the claim rules.
GRANT SELECT ON structs.influence_player_score_change TO structs_webapp;
COMMIT;
