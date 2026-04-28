-- Deploy structs-pg:trigger-player-pending-20260427-ugc-inclusion to pg
--
-- Two changes for the v0.16.0 UGC overhaul:
--
-- 1. PLAYER_PENDING_JOIN_PROXY now threads the pending row's username and
--    pfp into the `ugc` JSONB argument of signer.CREATE_TRANSACTION so the
--    chain receives the player's chosen name/pfp at registration time.
--
-- 2. PLAYER_PENDING_MERGE no longer inserts into structs.player_meta. The
--    chain is now the single source of truth for player UGC; the cache
--    handler cache.handle_event_player upserts player_meta from the chain
--    payload (see cache-trigger-add-queue-20260427-ugc-fields). The merge
--    trigger keeps its other responsibilities: clearing the pending tables
--    and threading the new player_id into player_discord and signer.role.

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


    CREATE OR REPLACE FUNCTION structs.PLAYER_PENDING_MERGE()
        RETURNS trigger AS
    $BODY$
    DECLARE
        pending_data RECORD;
        numrows INT;
    BEGIN
        DELETE FROM structs.player_external_pending
            WHERE player_external_pending.primary_address = NEW.primary_address;

        DELETE FROM structs.player_pending
            WHERE player_pending.primary_address = NEW.primary_address
            RETURNING * INTO pending_data;

        get diagnostics numrows = row_count;
        IF numrows = 0 THEN
            DELETE FROM structs.player_internal_pending
                WHERE player_internal_pending.primary_address = NEW.primary_address
                RETURNING * INTO pending_data;
            get diagnostics numrows = row_count;

            IF numrows > 0 THEN
                UPDATE structs.player_discord
                    SET player_id = NEW.id
                    WHERE role_id = pending_data.role_id;

                UPDATE signer.role
                    SET player_id = NEW.id,
                        status    = 'ready'
                    WHERE id = pending_data.role_id;
            END IF;
        END IF;

        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
