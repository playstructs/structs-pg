-- Verify structs-pg:table-planet-activity-20260909-api-struct-attack-gin on pg

BEGIN;

    DO $$
    DECLARE
        def text;
    BEGIN
        IF to_regclass('structs.planet_activity_attacker_player_block_time_planet_seq_idx') IS NOT NULL THEN
            RAISE EXCEPTION 'replaced attacker player btree still exists';
        END IF;

        SELECT pg_get_indexdef(to_regclass('structs.planet_activity_detail_gin'))
          INTO def;
        IF def IS NULL
           OR def NOT LIKE '%USING gin%'
           OR def NOT LIKE '%(detail jsonb_path_ops)%'
           OR def NOT LIKE '%category = ''struct_attack''%' THEN
            RAISE EXCEPTION 'planet activity struct_attack gin index unexpected: %', def;
        END IF;
    END
    $$;

ROLLBACK;
