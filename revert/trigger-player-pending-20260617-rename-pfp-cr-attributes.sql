-- Revert structs-pg:trigger-player-pending-20260617-rename-pfp-cr-attributes from pg
--
-- Restores PLAYER_PENDING_JOIN_PROXY to reference NEW.pfp_cr_attributes, the
-- body set by trigger-player-pending-20260612-pfp-cr-attributes-inclusion. This
-- runs before the column rename revert, so the old column name is valid here.

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

        IF NEW.pfp_cr_attributes IS NOT NULL THEN
            ugc := ugc || jsonb_build_object('player-pfp-cr-attributes', NEW.pfp_cr_attributes::text);
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
