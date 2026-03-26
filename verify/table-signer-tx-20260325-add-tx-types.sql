-- Verify structs-pg:table-signer-tx-20260325-add-tx-types on pg

BEGIN;

    SELECT 'guild-update-entry-rank'::structs.signer_tx_type;
    SELECT 'permission-guild-rank-set'::structs.signer_tx_type;
    SELECT 'permission-guild-rank-revoke'::structs.signer_tx_type;
    SELECT 'player-update-guild-rank'::structs.signer_tx_type;

ROLLBACK;
