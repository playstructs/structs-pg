-- Verify structs-pg:table-signer-tx-20260612-add-pfp-cr-attributes-tx-type on pg

BEGIN;

    SELECT 'player-update-pfp-cr-attributes'::structs.signer_tx_type;

ROLLBACK;
