-- Revert structs-pg:table-onboarding-20261110-telemetry-exclusion from pg

BEGIN;
DROP TABLE structs.onboarding_telemetry_exclusion;
COMMIT;
