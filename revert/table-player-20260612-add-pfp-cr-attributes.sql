-- Revert structs-pg:table-player-20260612-add-pfp-cr-attributes from pg

BEGIN;

    ALTER TABLE structs.player
        DROP COLUMN IF EXISTS pfp_client_render_attributes;

    ALTER TABLE structs.player_pending
        DROP COLUMN IF EXISTS pfp_cr_attributes;

COMMIT;
