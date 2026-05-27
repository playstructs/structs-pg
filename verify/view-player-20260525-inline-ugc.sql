-- Verify structs-pg:view-player-20260525-inline-ugc on pg

BEGIN;

    SELECT username, pfp FROM view.player WHERE FALSE;

ROLLBACK;
