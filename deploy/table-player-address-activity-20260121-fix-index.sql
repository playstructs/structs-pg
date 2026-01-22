-- Deploy structs-pg:table-player-address-activity-20260121-fix-index to pg

BEGIN;

    DROP INDEX player_address_activity_player_id_idx;
    CREATE INDEX player_address_activity_player_id_idx ON structs.player_address_activity (player_id);

COMMIT;
