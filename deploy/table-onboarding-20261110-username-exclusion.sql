-- Deploy structs-pg:table-onboarding-20261110-username-exclusion to pg

BEGIN;

CREATE TABLE structs.onboarding_telemetry_username_exclusion (
    username_regex TEXT PRIMARY KEY,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Compiling the expression rejects invalid regexes at import time.
    CHECK (length(username_regex) > 0 AND ('' ~ username_regex) IS NOT NULL)
);

COMMENT ON TABLE structs.onboarding_telemetry_username_exclusion IS
    'SQL-managed case-sensitive PostgreSQL regex rules matched against current player usernames. Use ^ and $ for whole-name matches. Matches exclude all linked onboarding sessions; renames can change historical report membership.';

GRANT SELECT ON structs.onboarding_telemetry_username_exclusion TO structs_webapp;

INSERT INTO structs.onboarding_telemetry_username_exclusion (username_regex, reason)
VALUES ('^T[0-9]{6}-?[0-9]{4}([0-9]{2})?$', 'Generated test accounts');

COMMIT;
