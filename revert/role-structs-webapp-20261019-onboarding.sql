-- Revert structs-pg:role-structs-webapp-20261019-onboarding from pg

BEGIN;

    REVOKE SELECT, INSERT ON structs.onboarding_progress FROM structs_webapp;
    REVOKE SELECT, INSERT ON structs.onboarding_session FROM structs_webapp;
    REVOKE SELECT ON structs.onboarding_step FROM structs_webapp;

COMMIT;
