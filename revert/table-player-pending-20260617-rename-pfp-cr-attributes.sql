-- Revert structs-pg:table-player-pending-20260617-rename-pfp-cr-attributes from pg

BEGIN;

    ALTER TABLE structs.player_pending
        RENAME COLUMN pfp_client_render_attributes TO pfp_cr_attributes;

COMMIT;
