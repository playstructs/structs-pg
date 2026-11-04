-- Verify structs-pg:table-onboarding-20261104-replay-catalog on pg

BEGIN;

    DO $$
    DECLARE
        total integer;
        heads integer;
        linked integer;
        branched integer;
    BEGIN
        SELECT count(*) INTO total
          FROM structs.onboarding_step
         WHERE content_version = 'tutorial-4-replay';
        IF total <> 51 THEN
            RAISE EXCEPTION 'tutorial-4-replay expected 51 rows, got %', total;
        END IF;

        IF EXISTS (
            SELECT 1 FROM structs.onboarding_step
             WHERE content_version = 'tutorial-4-replay'
               AND (phase <> 'tutorial' OR step_order NOT BETWEEN 1 AND 51)
        ) THEN
            RAISE EXCEPTION 'tutorial-4-replay must be tutorial phase only, step_order 1 to 51';
        END IF;

        IF EXISTS (
            SELECT 1 FROM structs.onboarding_step
             WHERE content_version = 'tutorial-4-replay'
               AND step_key IN ('orientation.tutorial_offer', 'tutorial.end.ftl_jump')
        ) THEN
            RAISE EXCEPTION 'tutorial-4-replay must not contain the offer or the FTL jump';
        END IF;

        SELECT count(*) INTO heads
          FROM structs.onboarding_step
         WHERE content_version = 'tutorial-4-replay'
           AND previous_step_key IS NULL;
        IF heads <> 1 OR NOT EXISTS (
            SELECT 1 FROM structs.onboarding_step
             WHERE content_version = 'tutorial-4-replay'
               AND step_key = 'tutorial.loading'
               AND step_order = 1
               AND previous_step_key IS NULL
        ) THEN
            RAISE EXCEPTION 'tutorial-4-replay expected one head, tutorial.loading at step_order 1, got % heads', heads;
        END IF;

        WITH RECURSIVE chain AS (
            SELECT step_key, step_order
              FROM structs.onboarding_step
             WHERE content_version = 'tutorial-4-replay'
               AND step_key = 'tutorial.loading'
            UNION ALL
            SELECT s.step_key, s.step_order
              FROM structs.onboarding_step s
              JOIN chain c ON s.previous_step_key = c.step_key
             WHERE s.content_version = 'tutorial-4-replay'
        )
        SELECT count(*) INTO linked FROM chain;

        IF linked <> 51 OR NOT EXISTS (
            SELECT 1 FROM structs.onboarding_step
             WHERE content_version = 'tutorial-4-replay'
               AND step_key = 'tutorial.end.certified'
               AND step_order = 51
               AND previous_step_key = 'tutorial.end.completed'
        ) THEN
            RAISE EXCEPTION 'tutorial-4-replay expected 51 linked steps ending at tutorial.end.certified, walked %', linked;
        END IF;

        IF EXISTS (
            SELECT 1 FROM structs.onboarding_step
             WHERE content_version = 'tutorial-4-replay'
               AND previous_step_key = 'tutorial.end.certified'
        ) THEN
            RAISE EXCEPTION 'tutorial.end.certified must be the last tutorial-4-replay step';
        END IF;

        SELECT count(*) INTO branched
          FROM (
                SELECT previous_step_key
                  FROM structs.onboarding_step
                 WHERE content_version = 'tutorial-4-replay'
                   AND previous_step_key IS NOT NULL
                 GROUP BY previous_step_key
                HAVING count(*) > 1
          ) d;
        IF branched <> 0 THEN
            RAISE EXCEPTION 'tutorial-4-replay has % steps with more than one successor', branched;
        END IF;

        IF EXISTS (
            SELECT 1
              FROM structs.onboarding_step r
              JOIN structs.onboarding_step t
                ON t.content_version = 'tutorial-4'
               AND t.step_key = r.step_key
             WHERE r.content_version = 'tutorial-4-replay'
               AND t.step_order <> r.step_order + 1
        ) THEN
            RAISE EXCEPTION 'tutorial-4-replay step_order must be tutorial-4 step_order minus 1';
        END IF;
    END
    $$;

ROLLBACK;
