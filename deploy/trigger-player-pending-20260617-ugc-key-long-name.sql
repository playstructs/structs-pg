-- Deploy structs-pg:trigger-player-pending-20260617-ugc-key-long-name to pg
--
-- The ugc key threaded by PLAYER_PENDING_JOIN_PROXY was named with the short
-- 'cr' form ('player-pfp-cr-attributes'). It should match the long
-- pfp_client_render_attributes naming, so the key becomes
-- 'player-pfp-client-render-attributes' (the off-chain broadcaster maps this
-- onto the playerPfpClientRenderAttributes message field). Only the ugc key
-- changes; the column reference (NEW.pfp_client_render_attributes) is unchanged.
-- Body is otherwise reproduced verbatim from
-- trigger-player-pending-20260617-rename-pfp-cr-attributes.

BEGIN;

    CREATE OR REPLACE FUNCTION structs.PLAYER_PENDING_JOIN_PROXY()
        RETURNS trigger AS
    $BODY$
    DECLARE
        ugc JSONB;
    BEGIN
        ugc := '{}'::JSONB;

        IF NEW.username <> '' AND NEW.username IS NOT NULL THEN
            ugc := jsonb_build_object('player-name', NEW.username);
        END IF;

        IF NEW.pfp <> '' AND NEW.pfp IS NOT NULL THEN
            ugc := ugc || jsonb_build_object('player-pfp', NEW.pfp);
        END IF;

        IF NEW.pfp_client_render_attributes IS NOT NULL THEN
            ugc := ugc || jsonb_build_object('player-pfp-client-render-attributes', NEW.pfp_client_render_attributes::text);
        END IF;

        PERFORM signer.CREATE_TRANSACTION(
            NEW.guild_id,
            512,
            'structs',
            'guild-membership-join-proxy',
            jsonb_build_array(NEW.primary_address, NEW.pubkey, NEW.signature),
            ugc
        );

        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
