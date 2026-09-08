-- Verify structs-pg:table-planet-activity-20260908-api-attacker-player-index on pg

BEGIN;

    DO $$
    DECLARE
        def text;
    BEGIN
        SELECT pg_get_indexdef(to_regclass('structs.planet_activity_attacker_player_block_time_planet_seq_idx'))
          INTO def;
        IF def IS NULL
           OR def NOT LIKE '%USING btree%'
           OR def NOT LIKE '%((detail ->> ''attackerPlayerId''::text)), block_height DESC NULLS LAST, "time" DESC, planet_id DESC, seq DESC)%'
           OR def NOT LIKE '%(detail ->> ''attackerPlayerId''::text) IS NOT NULL%' THEN
            RAISE EXCEPTION 'planet activity attacker player cursor index unexpected: %', def;
        END IF;
    END
    $$;

ROLLBACK;
