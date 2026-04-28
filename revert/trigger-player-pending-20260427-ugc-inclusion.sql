-- Revert structs-pg:trigger-player-pending-20260427-ugc-inclusion from pg
--
-- Restores the prior PLAYER_PENDING_JOIN_PROXY (no ugc threading) and the
-- prior PLAYER_PENDING_MERGE (which inserted into structs.player_meta).
-- These bodies are reproduced from cache-trigger-add-queue-20260424-player-update.sql
-- (the most recent prior CREATE OR REPLACE for both functions).

BEGIN;

    CREATE OR REPLACE FUNCTION structs.PLAYER_PENDING_JOIN_PROXY()
        RETURNS trigger AS
    $BODY$
    BEGIN
        -- 16 represents the Association permission
        PERFORM signer.CREATE_TRANSACTION(NEW.guild_id,16,'structs','guild-membership-join-proxy',jsonb_build_array(NEW.primary_address,NEW.pubkey,NEW.signature),'{}');
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

        DELETE FROM structs.player_external_pending WHERE player_external_pending.primary_address = NEW.primary_address;
        DELETE FROM structs.player_pending WHERE player_pending.primary_address = NEW.primary_address RETURNING * INTO pending_data;

        get diagnostics numrows = row_count;
        IF numrows = 0 THEN
            DELETE FROM structs.player_internal_pending WHERE player_internal_pending.primary_address = NEW.primary_address RETURNING * INTO pending_data;
            get diagnostics numrows = row_count;

            IF numrows > 0 THEN
                UPDATE structs.player_discord SET player_id = NEW.id WHERE role_id=pending_data.role_id;
                UPDATE signer.role SET player_id = NEW.id, status='ready' WHERE id=pending_data.role_id;
            END IF;
        END IF;

        IF numrows > 0 THEN
            INSERT INTO structs.player_meta
            VALUES (NEW.id,
                    pending_data.guild_id,
                    pending_data.username,
                    pending_data.pfp,
                    '',
                    NOW(),
                    NOW()
                   );

        END IF;

        RETURN NEW;
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
