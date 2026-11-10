-- Deploy structs-pg:table-onboarding-20261110-telemetry-exclusion to pg

BEGIN;

CREATE TABLE structs.onboarding_telemetry_exclusion (
    player_id CHARACTER VARYING PRIMARY KEY CHECK (player_id ~ '^1-[0-9]+$'),
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE structs.onboarding_telemetry_exclusion IS
    'SQL-managed player exclusions for onboarding and tutorial reports. Applies to all historical and future linked sessions; raw telemetry is retained. No player FK, so entries can precede indexer ingestion.';

GRANT SELECT ON structs.onboarding_telemetry_exclusion TO structs_webapp;

COMMIT;
