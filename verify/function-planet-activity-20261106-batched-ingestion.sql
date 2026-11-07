-- Verify structs-pg:function-planet-activity-20261106-batched-ingestion on pg

BEGIN;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgrelid = 'structs.planet_activity'::regclass
          AND tgname = 'planet_activity_attribute'
          AND tgfoid = 'structs.planet_activity_attribute()'::regprocedure
          AND tgenabled = 'O'
    ) THEN
        RAISE EXCEPTION 'planet activity attribution trigger missing or disabled';
    END IF;
    IF position('v_player_id := structs.object_owner' IN
                pg_get_functiondef('structs.planet_activity_attribute()'::regprocedure)) = 0 THEN
        RAISE EXCEPTION 'direct planet activity attribution paths missing';
    END IF;
END $$;
ROLLBACK;
