-- Deploy structs-pg:table-signer-tx-20260612-add-pfp-cr-attributes-tx-type to pg
--
-- structsd v0.18.0 adds the MsgPlayerUpdatePfpClientRenderAttributes chain
-- message (autocli command "player-update-pfp-cr-attributes"). Register the
-- matching signer_tx_type value so the tx wrappers in
-- function-signer-tx-20260612-pfp-cr-attributes can enqueue it.
--
-- Isolated in its own change so the new enum literal is committed before any
-- later change references it (a value added by ALTER TYPE ... ADD VALUE cannot
-- be used in the same transaction that adds it).

BEGIN;

    ALTER TYPE structs.signer_tx_type ADD VALUE 'player-update-pfp-cr-attributes';

COMMIT;
