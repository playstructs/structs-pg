-- Verify structs-pg:table-player-pending-20260617-rename-pfp-cr-attributes on pg

BEGIN;

    SELECT pfp_client_render_attributes FROM structs.player_pending WHERE FALSE;

ROLLBACK;
