-- Verify structs-pg:table-planet-activity-player-20260915-attribution on pg
--
-- Structural checks, then a functional one: insert a planet_activity row for a
-- real struct inside this transaction and confirm the trigger attributed it
-- to the struct's owner. Rolled back; the notify trigger's pg_notify is
-- discarded with the transaction.

BEGIN;

    SELECT time, planet_id, seq, player_id, role, category, block_height
      FROM structs.planet_activity_player WHERE FALSE;

    DO $$
    DECLARE
        v_struct  CHARACTER VARYING;
        v_owner   CHARACTER VARYING;
        v_planet  CHARACTER VARYING;
        v_got     CHARACTER VARYING;
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM timescaledb_information.hypertables
             WHERE hypertable_schema = 'structs' AND hypertable_name = 'planet_activity_player'
        ) THEN
            RAISE EXCEPTION 'structs.planet_activity_player is not a hypertable';
        END IF;

        IF to_regclass('structs.planet_activity_player_feed_idx') IS NULL
           OR to_regclass('structs.planet_activity_player_category_feed_idx') IS NULL THEN
            RAISE EXCEPTION 'expected feed indexes on structs.planet_activity_player';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM pg_trigger
             WHERE tgrelid = 'structs.planet_activity'::regclass
               AND tgname = 'planet_activity_attribute'
        ) THEN
            RAISE EXCEPTION 'trigger planet_activity_attribute missing on structs.planet_activity';
        END IF;

        SELECT s.id, s.owner INTO v_struct, v_owner
          FROM structs.struct s
         WHERE s.owner IS NOT NULL AND s.owner <> ''
           AND EXISTS (SELECT 1 FROM structs.player_object po WHERE po.object_id = s.id)
         LIMIT 1;

        IF v_struct IS NULL THEN
            RAISE NOTICE 'no struct with an owner; skipping functional check';
            RETURN;
        END IF;

        SELECT p.id INTO v_planet FROM structs.planet p LIMIT 1;

        INSERT INTO structs.planet_activity (time, seq, planet_id, category, detail, block_height)
        VALUES (now(), 2147483000, v_planet, 'struct_status',
                jsonb_build_object('struct_id', v_struct, 'status', '1', 'status_old', '0'), 0);

        SELECT pap.player_id INTO v_got
          FROM structs.planet_activity_player pap
         WHERE pap.planet_id = v_planet AND pap.seq = 2147483000 AND pap.role = 'owner';

        IF v_got IS DISTINCT FROM v_owner THEN
            RAISE EXCEPTION 'trigger attributed struct % to % (expected %)', v_struct, v_got, v_owner;
        END IF;
    END
    $$;

ROLLBACK;
