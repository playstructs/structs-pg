-- Deploy structs-pg:table-signer-tx-20260427-add-tx-types to pg

BEGIN;

    ALTER TYPE structs.signer_tx_type ADD VALUE 'guild-update-name';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'guild-update-pfp';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'player-update-name';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'player-update-pfp';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'substation-update-name';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'substation-update-pfp';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'planet-update-name';

COMMIT;
