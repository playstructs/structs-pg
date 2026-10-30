-- Verify structs-pg:table-signer-tx-20261030-build-cancel-type on pg
BEGIN;
SELECT 'struct-build-cancel'::structs.signer_tx_type;
ROLLBACK;
