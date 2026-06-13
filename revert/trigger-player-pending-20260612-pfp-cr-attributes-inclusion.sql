-- Revert structs-pg:trigger-player-pending-20260612-pfp-cr-attributes-inclusion from pg
--
-- Restores PLAYER_PENDING_JOIN_PROXY to its prior body (no pfp_cr_attributes
-- threading), reproduced verbatim from
-- trigger-player-pending-20260427-ugc-inclusion.sql. PLAYER_PENDING_MERGE is
-- not touched.

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
