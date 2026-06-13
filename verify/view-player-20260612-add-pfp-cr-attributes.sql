-- Verify structs-pg:view-player-20260612-add-pfp-cr-attributes on pg

BEGIN;

    SELECT pfp_client_render_attributes FROM view.player WHERE FALSE;

ROLLBACK;
