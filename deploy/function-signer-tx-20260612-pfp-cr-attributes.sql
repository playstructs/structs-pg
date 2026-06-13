-- Deploy structs-pg:function-signer-tx-20260612-pfp-cr-attributes to pg
--
-- structsd v0.18.0 adds MsgPlayerUpdatePfpClientRenderAttributes. The chain's
-- permission check accepts EITHER PermUpdate (4) on the target player
-- (self-service) OR PermGuildUGCUpdate (16777216) on the actor's guild (guild
-- moderation), exactly like the player name/pfp UGC messages. Because
-- signer.CREATE_TRANSACTION enforces an exact bitwise permission match against
-- a single object_id, each path gets its own wrapper:
--
--   tx_player_update_pfp_cr_attributes          self-service (object = player)
--   tx_guild_moderate_player_pfp_cr_attributes  guild moderation (object = guild)
--
-- Args mirror MsgPlayerUpdatePfpClientRenderAttributes(playerId,
-- pfpClientRenderAttributes); the chain validates/compacts the JSON-object
-- string itself.

BEGIN;

    -- Self-service (PermUpdate = 4 on the target player)
    CREATE OR REPLACE FUNCTION signer.tx_player_update_pfp_cr_attributes(
        _player_id         CHARACTER VARYING,
        _pfp_cr_attributes CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,4,'structs','player-update-pfp-cr-attributes',jsonb_build_array(_player_id, _pfp_cr_attributes),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

    -- Guild moderation (PermGuildUGCUpdate = 16777216 on the guild)
    CREATE OR REPLACE FUNCTION signer.tx_guild_moderate_player_pfp_cr_attributes(
        _player_id         CHARACTER VARYING,
        _guild_id          CHARACTER VARYING,
        _target_player_id  CHARACTER VARYING,
        _pfp_cr_attributes CHARACTER VARYING
    ) RETURNS void AS
    $BODY$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_guild_id,16777216,'structs','player-update-pfp-cr-attributes',jsonb_build_array(_target_player_id, _pfp_cr_attributes),'{}');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
