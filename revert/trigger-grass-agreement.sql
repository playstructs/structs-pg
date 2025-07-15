-- Revert structs-pg:trigger-grass-agreement from pg

BEGIN;

DROP TRIGGER IF EXISTS AGREEMENT_NOTIFY ON structs.agreement;
DROP FUNCTION IF EXISTS structs.AGREEMENT_NOTIFY();

COMMIT;
