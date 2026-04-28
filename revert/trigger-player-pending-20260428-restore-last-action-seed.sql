-- Revert structs-pg:trigger-player-pending-20260428-restore-last-action-seed from pg
--
-- Restores PLAYER_PENDING_MERGE to the version shipped in
-- trigger-player-pending-20260427-ugc-inclusion (no lastAction seed).
--
-- The backfilled grid rows are NOT removed: they may have been updated
-- by the chain since deploy, and undoing them risks data loss.

BEGIN;

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
