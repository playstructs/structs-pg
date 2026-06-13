-- Deploy structs-pg:table-player-20260612-add-pfp-cr-attributes to pg
--
-- structsd v0.18.0 adds Player.pfpClientRenderAttributes (a compacted JSON
-- object string describing how the client should render the player's locally
-- generated profile picture).
--
--   structs.player.pfp_client_render_attributes
--       The chain-sourced value. CHARACTER VARYING to mirror the sibling
--       username/pfp columns and the chain's string field; sync-state writes
--       the raw string.
--
--   structs.player_pending.pfp_cr_attributes
--       Carries the chosen attributes through the proxy-join flow. JSONB so
--       the webapp can set a JSON object directly; PLAYER_PENDING_JOIN_PROXY
--       serializes it to a compacted string when threading it into the ugc
--       argument of signer.CREATE_TRANSACTION (see
--       trigger-player-pending-20260612-pfp-cr-attributes-inclusion).

BEGIN;

    ALTER TABLE structs.player
        ADD COLUMN pfp_client_render_attributes CHARACTER VARYING;

    ALTER TABLE structs.player_pending
        ADD COLUMN pfp_cr_attributes JSONB;

COMMIT;
