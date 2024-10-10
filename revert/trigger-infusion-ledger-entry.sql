-- Revert structs-pg:trigger-infusion-ledger-entry from pg

BEGIN;

DROP FUNCTION structs.INFUSION_LEDGER_ENTRY();

COMMIT;
