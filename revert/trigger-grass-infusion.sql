-- Revert structs-pg:trigger-grass-infusion from pg

BEGIN;

DROP TRIGGER IF EXISTS INFUSION_NOTIFY ON structs.infusion;
DROP FUNCTION IF EXISTS structs.INFUSION_NOTIFY();

COMMIT;
