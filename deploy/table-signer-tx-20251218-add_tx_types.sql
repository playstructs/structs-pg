-- Deploy structs-pg:table-signer-tx-20251218-add_tx_types to pg

BEGIN;

    ALTER TYPE structs.signer_tx_type ADD VALUE 'agreement-capacity-decrease';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'agreement-capacity-increase';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'agreement-close';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'agreement-duration-increase';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'agreement-open';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'guild-bank-confiscate-and-burn';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'guild-bank-mint';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'player-resume';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'player-send';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'provider-create';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'provider-delete';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'provider-guild-grant';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'provider-guild-revoke';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'provider-update-access-policy';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'provider-update-capacity-maximum';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'provider-update-capacity-minimum';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'provider-update-duration-maximum';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'provider-update-duration-minimum';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'provider-withdraw-balance';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'reactor-begin-migration';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'reactor-cancel-defusion';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'reactor-defuse';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'reactor-infuse';

COMMIT;
