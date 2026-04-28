-- Deploy structs-pg:trigger-player-pending-20260428-restore-last-action-seed to pg
--
-- Restores the structs.grid 'lastAction' seed row that PLAYER_PENDING_MERGE
-- used to insert for each new player. The seed was originally added in
-- trigger-player-pending.sql, then silently dropped by the Apr 24
-- cache-trigger-add-queue-20260424-player-update.sql rewrite of the same
-- function and again by the Apr 27 trigger-player-pending-20260427-ugc-inclusion
-- rewrite. Without it, the webapp query
--
--     SELECT val AS last_action_block_height
--     FROM   grid
--     WHERE  object_id = :player_id
--       AND  attribute_type = 'lastAction'
--
-- returns zero rows for any player onboarded after Apr 24 until the chain
-- emits its first lastAction grid attribute update for that player.
--
-- The seed value is now 1 (was 0 historically) so consumers can treat the
-- absence of any real on-chain action as "block 1" rather than the genesis
-- placeholder.
--
-- Also backfills the seed row for any player that is missing one.

BEGIN;

    CREATE OR REPLACE FUNCTION structs.PLAYER_PENDING_MERGE()
        RETURNS trigger AS
    $BODY$
    DECLARE
        pending_data RECORD;
        numrows INT;
    BEGIN
        INSERT INTO structs.grid
            VALUES ('11-' || NEW.id, 'lastAction', 'player', NEW.index, NEW.id, 1, NOW())
            ON CONFLICT (id) DO NOTHING;

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

    -- Backfill: any existing player missing its 'lastAction' grid row
    INSERT INTO structs.grid (id, attribute_type, object_type, object_index, object_id, val, updated_at)
    SELECT '11-' || p.id, 'lastAction', 'player', p.index, p.id, 1, NOW()
    FROM   structs.player p
    WHERE  NOT EXISTS (
        SELECT 1
        FROM   structs.grid g
        WHERE  g.object_id      = p.id
          AND  g.attribute_type = 'lastAction'
    );

COMMIT;
