-- Deploy structs-pg:trigger-player-pending-20260612-pfp-cr-attributes-inclusion to pg
--
-- structsd v0.18.0 adds playerPfpClientRenderAttributes (field 8) to
-- MsgGuildMembershipJoinProxy. PLAYER_PENDING_JOIN_PROXY now threads the
-- pending row's pfp_cr_attributes into the ugc JSONB under the
-- 'player-pfp-cr-attributes' key (the off-chain broadcaster maps this onto the
-- new message field, alongside the existing 'player-name' / 'player-pfp').
--
-- pfp_cr_attributes is JSONB on player_pending; it is cast to its compacted
-- text form so the ugc value is the JSON-object string the chain expects.
--
-- Only PLAYER_PENDING_JOIN_PROXY changes here; PLAYER_PENDING_MERGE keeps the
-- body set by trigger-player-pending-20260428-restore-last-action-seed.

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
