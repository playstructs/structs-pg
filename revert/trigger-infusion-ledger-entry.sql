-- Revert structs-pg:trigger-infusion-ledger-entry from pg

BEGIN;

DROP TRIGGER IF EXISTS ADD_INFUSION_LEDGER_ENTRY ON structs.infusion;
DROP FUNCTION IF EXISTS structs.INFUSION_LEDGER_ENTRY();

COMMIT;
