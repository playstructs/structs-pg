-- Verify structs-pg:table-signer-tx-20261030-membership-revoke-type on pg
BEGIN;
SELECT 'guild-membership-invite-revoke'::structs.signer_tx_type;
ROLLBACK;
