-- Deploy structs-pg:trigger-grass-player-20260525-drop-meta-notify to pg
--
-- player_meta is retired; chain UGC updates on structs.player use player_consensus.
-- PLAYER_META_NOTIFY was dropped with player_meta CASCADE; remove the orphan function.

BEGIN;

    DROP FUNCTION IF EXISTS structs.PLAYER_META_NOTIFY();

COMMIT;
