-- Deploy structs-pg:trigger-player-pending-20260617-rename-pfp-cr-attributes to pg
--
-- player_pending.pfp_cr_attributes was renamed to pfp_client_render_attributes
-- in table-player-pending-20260617-rename-pfp-cr-attributes. plpgsql resolves
-- column references at execution time, so PLAYER_PENDING_JOIN_PROXY must be
-- recreated to reference the new column name; otherwise the next proxy-join
-- insert errors. The ugc key ('player-pfp-cr-attributes') is the chain message
-- key and is unchanged. Body is otherwise reproduced verbatim from
-- trigger-player-pending-20260612-pfp-cr-attributes-inclusion.

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
            ugc := ugc || jsonb_build_object('player-pfp-cr-attributes', NEW.pfp_client_render_attributes::text);
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
