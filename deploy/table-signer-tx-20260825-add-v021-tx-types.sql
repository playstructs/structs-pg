-- Deploy structs-pg:table-signer-tx-20260825-add-v021-tx-types to pg
--
-- structsd v0.21.0 adds MsgGuildBankConvert, MsgGuildBankConvertToken,
-- MsgGuildUpdateBankConvertInFee, MsgGuildUpdateBankConvertOutFee, and
-- MsgReactorRestart. Register the matching signer_tx_type values (autocli
-- commands) so function-signer-tx-20260825-v021-messages can enqueue them.
--
-- Isolated in its own change so the new enum literals are committed before any
-- later change references them (ALTER TYPE ... ADD VALUE cannot be used in the
-- same transaction that adds the value).

BEGIN;

    ALTER TYPE structs.signer_tx_type ADD VALUE 'guild-bank-convert';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'guild-bank-convert-token';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'guild-update-bank-convert-in-fee';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'guild-update-bank-convert-out-fee';
    ALTER TYPE structs.signer_tx_type ADD VALUE 'reactor-restart';

COMMIT;
