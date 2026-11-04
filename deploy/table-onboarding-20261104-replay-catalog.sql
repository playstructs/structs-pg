-- Deploy structs-pg:table-onboarding-20261104-replay-catalog to pg
--
-- tutorial-4-replay: Combat Training re-run from the Account menu. It is the
-- tutorial-4 tutorial line without the offer and the FTL jump, so it runs
-- from tutorial.loading to tutorial.end.certified. There is no signup phase.
-- See docs/onboarding-telemetry-handoff.md.

BEGIN;

    INSERT INTO structs.onboarding_step
        (content_version, phase, step_order, step_key, previous_step_key)
    SELECT 'tutorial-4-replay',
           phase,
           step_order - 1,
           step_key,
           CASE WHEN step_key = 'tutorial.loading' THEN NULL ELSE previous_step_key END
      FROM structs.onboarding_step
     WHERE content_version = 'tutorial-4'
       AND phase = 'tutorial'
       AND step_key NOT IN ('orientation.tutorial_offer', 'tutorial.end.ftl_jump');

    COMMENT ON TABLE structs.onboarding_session IS
        'One onboarding run, inserted once when the run starts: at signup, at the tutorial offer in a later visit, or at tutorial.loading for a replay. Identity that arrives later is not written here.';

    COMMENT ON TABLE structs.onboarding_progress IS
        'Insert-only onboarding events. kind is reached or skipped. player_id is set only on reached rows for signup.employee_record, orientation.tutorial_offer, and tutorial.loading in tutorial-4-replay. A session can have more than one.';

COMMIT;
