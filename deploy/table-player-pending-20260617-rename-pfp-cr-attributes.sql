-- Deploy structs-pg:table-player-pending-20260617-rename-pfp-cr-attributes to pg
--
-- Rename structs.player_pending.pfp_cr_attributes to pfp_client_render_attributes
-- so the pending column matches its sibling on structs.player. The column stays
-- JSONB; PLAYER_PENDING_JOIN_PROXY is updated to reference the new name in
-- trigger-player-pending-20260617-rename-pfp-cr-attributes.

BEGIN;

    ALTER TABLE structs.player_pending
        RENAME COLUMN pfp_cr_attributes TO pfp_client_render_attributes;

COMMIT;
