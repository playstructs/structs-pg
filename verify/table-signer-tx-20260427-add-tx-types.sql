-- Verify structs-pg:table-signer-tx-20260427-add-tx-types on pg

BEGIN;

    SELECT 'guild-update-name'::structs.signer_tx_type;
    SELECT 'guild-update-pfp'::structs.signer_tx_type;
    SELECT 'player-update-name'::structs.signer_tx_type;
    SELECT 'player-update-pfp'::structs.signer_tx_type;
    SELECT 'substation-update-name'::structs.signer_tx_type;
    SELECT 'substation-update-pfp'::structs.signer_tx_type;
    SELECT 'planet-update-name'::structs.signer_tx_type;

ROLLBACK;
