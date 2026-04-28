-- Verify structs-pg:trigger-player-pending-20260427-ugc-inclusion on pg

BEGIN;

    SELECT 'structs.player_pending_join_proxy()'::regprocedure;
    SELECT 'structs.player_pending_merge()'::regprocedure;

ROLLBACK;
