-- Verify structs-pg:function-planet-activity-20260915-players on pg
--
-- Exercises every branch with synthetic detail; no table reads beyond
-- ownership lookups of ids that do not exist (must yield no rows, not errors).

BEGIN;

    DO $$
    DECLARE
        n int;
    BEGIN
        IF to_regprocedure('structs.object_owner(character varying)') IS NULL THEN
            RAISE EXCEPTION 'expected structs.object_owner(character varying)';
        END IF;
        IF to_regprocedure('structs.planet_activity_players(structs.grass_category, character varying, jsonb)') IS NULL THEN
            RAISE EXCEPTION 'expected structs.planet_activity_players(grass_category, varchar, jsonb)';
        END IF;

        -- attacker + two distinct targets (one duplicated) => 3 rows
        SELECT count(*) INTO n FROM structs.planet_activity_players(
            'struct_attack', '2-0',
            '{"attackerPlayerId":"1-A","eventAttackShotDetail":[{"targetPlayerId":"1-B"},{"targetPlayerId":"1-C"},{"targetPlayerId":"1-B"}]}');
        IF n <> 3 THEN RAISE EXCEPTION 'struct_attack: expected 3 rows, got %', n; END IF;

        IF NOT EXISTS (SELECT 1 FROM structs.planet_activity_players('struct_attack', '2-0',
            '{"attackerPlayerId":"1-A","eventAttackShotDetail":[]}') WHERE player_id = '1-A' AND role = 'attacker')
        THEN RAISE EXCEPTION 'struct_attack: attacker role missing'; END IF;

        -- unknown struct owner => no rows, no error
        SELECT count(*) INTO n FROM structs.planet_activity_players(
            'struct_status', '2-0', '{"struct_id":"5-999999999","status":"1"}');
        IF n <> 0 THEN RAISE EXCEPTION 'struct_status with unknown struct: expected 0 rows, got %', n; END IF;

        -- empty / null detail => no rows, no error
        SELECT count(*) INTO n FROM structs.planet_activity_players('shield_change', '2-999999999', '{}');
        IF n <> 0 THEN RAISE EXCEPTION 'shield_change with unknown planet: expected 0 rows, got %', n; END IF;
        SELECT count(*) INTO n FROM structs.planet_activity_players('struct_attack', '2-0', NULL);
        IF n <> 0 THEN RAISE EXCEPTION 'null detail: expected 0 rows, got %', n; END IF;

        IF structs.object_owner('5-999999999') IS NOT NULL OR structs.object_owner('') IS NOT NULL
           OR structs.object_owner(NULL) IS NOT NULL THEN
            RAISE EXCEPTION 'object_owner should be NULL for unknown/empty ids';
        END IF;
    END
    $$;

ROLLBACK;
