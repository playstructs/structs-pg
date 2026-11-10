-- Revert structs-pg:table-onboarding-20261110-username-exclusion from pg

BEGIN;
DROP TABLE structs.onboarding_telemetry_username_exclusion;
COMMIT;
