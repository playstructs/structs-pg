-- Deploy structs-pg:role-structs-webapp-20261019-onboarding to pg
--
-- The webapp inserts onboarding sessions and progress. It does not update
-- them. The step catalog is reference data.

BEGIN;

    GRANT SELECT ON structs.onboarding_step TO structs_webapp;

    GRANT SELECT, INSERT ON structs.onboarding_session TO structs_webapp;
    GRANT SELECT, INSERT ON structs.onboarding_progress TO structs_webapp;

COMMIT;
