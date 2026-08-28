-- Verify structs-pg:table-signer-tx-20260825-add-v021-tx-types on pg

BEGIN;

    SELECT 'guild-bank-convert'::structs.signer_tx_type;
    SELECT 'guild-bank-convert-token'::structs.signer_tx_type;
    SELECT 'guild-update-bank-convert-in-fee'::structs.signer_tx_type;
    SELECT 'guild-update-bank-convert-out-fee'::structs.signer_tx_type;
    SELECT 'reactor-restart'::structs.signer_tx_type;

ROLLBACK;
