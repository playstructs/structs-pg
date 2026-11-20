-- Deploy structs-pg:influence-contest-20261117 to pg
-- The November 17 rehearsal is retired. Keep this change in the Sqitch plan
-- for existing registries, but do not create it during a new/lagging upgrade.
-- A locally occupied ID 2 or different rehearsal rules must not block the
-- subsequent influence-official-contest-20261120 reset. That reset alone owns
-- deletion of test data and registration of official contest 1.
BEGIN;
SELECT contest_id FROM structs.influence_contest WHERE false;
COMMIT;
