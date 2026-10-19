-- Verify structs-pg:table-onboarding-20261019 on pg

BEGIN;

    DO $$
    DECLARE
        pk text;
        idx text;
        heads integer;
        linked integer;
        branched integer;
    BEGIN
        SELECT string_agg(a.attname, ',' ORDER BY k.ord)
          INTO pk
          FROM pg_constraint c
          JOIN pg_class t ON t.oid = c.conrelid
          JOIN pg_namespace n ON n.oid = t.relnamespace
          JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS k(attnum, ord) ON TRUE
          JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = k.attnum
         WHERE n.nspname = 'structs'
           AND t.relname = 'onboarding_session'
           AND c.contype = 'p';
        IF pk IS DISTINCT FROM 'session_id' THEN
            RAISE EXCEPTION 'onboarding_session primary key expected (session_id), got %', pk;
        END IF;

        SELECT string_agg(a.attname, ',' ORDER BY k.ord)
          INTO pk
          FROM pg_constraint c
          JOIN pg_class t ON t.oid = c.conrelid
          JOIN pg_namespace n ON n.oid = t.relnamespace
          JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS k(attnum, ord) ON TRUE
          JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = k.attnum
         WHERE n.nspname = 'structs'
           AND t.relname = 'onboarding_progress'
           AND c.contype = 'p';
        IF pk IS DISTINCT FROM 'session_id,step_key,kind' THEN
            RAISE EXCEPTION 'onboarding_progress primary key expected (session_id, step_key, kind), got %', pk;
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM pg_constraint c
              JOIN pg_class t ON t.oid = c.conrelid
              JOIN pg_namespace n ON n.oid = t.relnamespace
             WHERE n.nspname = 'structs'
               AND t.relname = 'onboarding_step'
               AND c.contype = 'f'
               AND c.condeferrable
               AND c.condeferred
        ) THEN
            RAISE EXCEPTION 'onboarding_step.previous_step_key foreign key must be deferrable initially deferred';
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM pg_constraint c
              JOIN pg_class t ON t.oid = c.conrelid
              JOIN pg_namespace n ON n.oid = t.relnamespace
             WHERE n.nspname = 'structs'
               AND t.relname = 'onboarding_progress'
               AND c.contype = 'c'
               AND pg_get_constraintdef(c.oid) LIKE '%reached%'
               AND pg_get_constraintdef(c.oid) LIKE '%skipped%'
        ) THEN
            RAISE EXCEPTION 'onboarding_progress.kind must be limited to reached and skipped';
        END IF;

        SELECT pg_get_indexdef(to_regclass('structs.onboarding_progress_player_idx')) INTO idx;
        IF idx IS NULL OR idx NOT LIKE '%(player_id)%' OR idx NOT LIKE '%player_id IS NOT NULL%' THEN
            RAISE EXCEPTION 'onboarding_progress_player_idx expected a partial index on player_id, got %', idx;
        END IF;

        -- Main lines are a single linked list. The FAQ is the extra null
        -- previous in signup, and nothing points at it.
        SELECT count(*) INTO heads
          FROM structs.onboarding_step
         WHERE content_version = 'tutorial-4'
           AND phase = 'signup'
           AND previous_step_key IS NULL;
        IF heads <> 2 THEN
            RAISE EXCEPTION 'tutorial-4 signup expected 2 rows with no previous (connecting and the FAQ), got %', heads;
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM structs.onboarding_step
             WHERE content_version = 'tutorial-4'
               AND step_key = 'signup.recovery_key_faq'
               AND step_order = 0
               AND previous_step_key IS NULL
        ) THEN
            RAISE EXCEPTION 'signup.recovery_key_faq must be step_order 0 with no previous';
        END IF;

        IF EXISTS (
            SELECT 1 FROM structs.onboarding_step
             WHERE content_version = 'tutorial-4'
               AND previous_step_key = 'signup.recovery_key_faq'
        ) THEN
            RAISE EXCEPTION 'no step may list signup.recovery_key_faq as its previous';
        END IF;

        WITH RECURSIVE chain AS (
            SELECT step_key, step_order
              FROM structs.onboarding_step
             WHERE content_version = 'tutorial-4'
               AND step_key = 'signup.connecting'
            UNION ALL
            SELECT s.step_key, s.step_order
              FROM structs.onboarding_step s
              JOIN chain c ON s.previous_step_key = c.step_key
             WHERE s.content_version = 'tutorial-4'
        )
        SELECT count(*) INTO linked FROM chain;

        IF linked <> 12 OR NOT EXISTS (
            SELECT 1 FROM structs.onboarding_step
             WHERE content_version = 'tutorial-4'
               AND step_key = 'signup.employee_record'
               AND step_order = 12
               AND previous_step_key = 'signup.submit'
        ) THEN
            RAISE EXCEPTION 'tutorial-4 signup main line expected 12 steps ending at signup.employee_record, walked %', linked;
        END IF;

        WITH RECURSIVE chain AS (
            SELECT step_key, step_order
              FROM structs.onboarding_step
             WHERE content_version = 'tutorial-4'
               AND step_key = 'orientation.tutorial_offer'
            UNION ALL
            SELECT s.step_key, s.step_order
              FROM structs.onboarding_step s
              JOIN chain c ON s.previous_step_key = c.step_key
             WHERE s.content_version = 'tutorial-4'
        )
        SELECT count(*) INTO linked FROM chain;

        IF linked <> 53 OR NOT EXISTS (
            SELECT 1 FROM structs.onboarding_step
             WHERE content_version = 'tutorial-4'
               AND step_key = 'tutorial.end.ftl_jump'
               AND step_order = 53
               AND previous_step_key = 'tutorial.end.certified'
        ) THEN
            RAISE EXCEPTION 'tutorial-4 tutorial line expected 53 steps ending at tutorial.end.ftl_jump, walked %', linked;
        END IF;

        SELECT count(*) INTO branched
          FROM (
                SELECT previous_step_key
                  FROM structs.onboarding_step
                 WHERE content_version = 'tutorial-4'
                   AND previous_step_key IS NOT NULL
                 GROUP BY previous_step_key
                HAVING count(*) > 1
          ) d;
        IF branched <> 0 THEN
            RAISE EXCEPTION 'tutorial-4 has % steps with more than one successor', branched;
        END IF;
    END
    $$;

ROLLBACK;
