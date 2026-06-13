-- Verify structs-pg:table-player-20260612-add-pfp-cr-attributes on pg

BEGIN;

    SELECT pfp_client_render_attributes FROM structs.player        WHERE FALSE;
    SELECT pfp_cr_attributes            FROM structs.player_pending WHERE FALSE;

ROLLBACK;
