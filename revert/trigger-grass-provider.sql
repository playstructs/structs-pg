-- Revert structs-pg:trigger-grass-provider from pg

BEGIN;

DROP TRIGGER IF EXISTS PROVIDER_NOTIFY ON structs.provider;
DROP FUNCTION IF EXISTS structs.PROVIDER_NOTIFY();

COMMIT;
