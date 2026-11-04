-- Revert structs-pg:table-onboarding-20261104-replay-catalog from pg

BEGIN;

    DELETE FROM structs.onboarding_step
     WHERE content_version = 'tutorial-4-replay';

    COMMENT ON TABLE structs.onboarding_session IS
        'One onboarding run, inserted once when signup starts. Identity that arrives later is not written here.';

    COMMENT ON TABLE structs.onboarding_progress IS
        'Insert-only onboarding events. kind is reached or skipped. player_id is set only on the signup.employee_record reached row.';

COMMIT;
