-- Verify structs-pg:table-mini-game-progress-20261016 on pg

BEGIN;

    DO $$
    DECLARE
        expected text[] := ARRAY[
            'player_id',
            'interface_name',
            'game_name',
            'score',
            'created_at',
            'updated_at'
        ];
        col text;
        pk text;
    BEGIN
        FOREACH col IN ARRAY expected
        LOOP
            IF NOT EXISTS (
                SELECT 1
                  FROM information_schema.columns
                 WHERE table_schema = 'structs'
                   AND table_name = 'mini_game_progress'
                   AND column_name = col
            ) THEN
                RAISE EXCEPTION 'expected structs.mini_game_progress.% to exist', col;
            END IF;
        END LOOP;

        IF NOT EXISTS (
            SELECT 1
              FROM information_schema.columns
             WHERE table_schema = 'structs'
               AND table_name = 'mini_game_progress'
               AND column_name = 'score'
               AND data_type = 'integer'
               AND is_nullable = 'NO'
        ) THEN
            RAISE EXCEPTION 'structs.mini_game_progress.score must be integer NOT NULL';
        END IF;

        SELECT string_agg(a.attname, ',' ORDER BY k.ord)
          INTO pk
          FROM pg_constraint c
          JOIN pg_class t ON t.oid = c.conrelid
          JOIN pg_namespace n ON n.oid = t.relnamespace
          JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS k(attnum, ord) ON TRUE
          JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = k.attnum
         WHERE n.nspname = 'structs'
           AND t.relname = 'mini_game_progress'
           AND c.contype = 'p';

        IF pk IS DISTINCT FROM 'player_id,interface_name,game_name' THEN
            RAISE EXCEPTION
                'mini_game_progress primary key expected (player_id, interface_name, game_name), got %',
                pk;
        END IF;
    END
    $$;

ROLLBACK;
