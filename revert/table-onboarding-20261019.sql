-- Revert structs-pg:table-onboarding-20261019 from pg

BEGIN;

    DROP TABLE IF EXISTS structs.onboarding_progress;
    DROP TABLE IF EXISTS structs.onboarding_session;
    DROP TABLE IF EXISTS structs.onboarding_step;

COMMIT;
