-- Revert structs-pg:trigger-grass-player-20260525-drop-meta-notify from pg
--
-- This change only dropped the orphan function. DROP TABLE player_meta
-- CASCADE in table-player-20260525-add-username-pfp already removed the
-- trigger, and that change is still deployed when this one reverts, so
-- structs.player_meta does not exist yet. Recreating the trigger here
-- aborts a full rollback. The trigger is restored when that earlier
-- change reverts and the table exists again.

BEGIN;

    CREATE OR REPLACE FUNCTION structs.PLAYER_META_NOTIFY() RETURNS trigger AS
    $BODY$
    DECLARE
        payload TEXT;
    BEGIN
        payload := (to_jsonb(NEW) || jsonb_build_object('subject','structs.player.' || NEW.guild_id || '.' || NEW.id, 'category', 'player_meta'))::TEXT;

        IF length(payload) > 7995 THEN
            payload := jsonb_build_object(
                    'subject','structs.player.' || NEW.guild_id || '.' || NEW.id,
                    'category', 'player_meta',
                    'id', NEW.id,
                    'updated_at', NEW.updated_at,
                    'stub', 'true')::TEXT;
        END IF;

        PERFORM pg_notify('grass', payload);

        RETURN NEW;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE SECURITY DEFINER COST 100;

COMMIT;
