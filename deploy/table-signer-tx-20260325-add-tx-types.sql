-- Deploy structs-pg:table-signer-tx-20260325-add-tx-types to pg

BEGIN;

    ALTER TYPE structs.signer_tx_type ADD VALUE 'guild-update-entry-rank';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'permission-guild-rank-set';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'permission-guild-rank-revoke';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'player-update-guild-rank';

COMMIT;
