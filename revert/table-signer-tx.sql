-- Revert structs-pg:table-signer-tx from pg

BEGIN;

DROP FUNCTION IF EXISTS signer.CREATE_TRANSACTION(_object_id CHARACTER VARYING, _permission_requirement INTEGER, _module structs.signer_tx_module, _command structs.signer_tx_type, _args JSONB, _flags JSONB);
DROP FUNCTION IF EXISTS signer.CLAIM_INTERNAL_TRANSACTION();
DROP FUNCTION IF EXISTS signer.TRANSACTION_ERROR(transaction_id INTEGER, transaction_error TEXT);
DROP FUNCTION IF EXISTS signer.TRANSACTION_BROADCAST_RESULTS(transaction_id INTEGER, transaction_output TEXT);
DROP FUNCTION IF EXISTS signer.tx_bank_send(_player_id CHARACTER VARYING, _amount NUMERIC, _denom CHARACTER VARYING, _destination_player_id CHARACTER VARYING);
DROP FUNCTION IF EXISTS signer.tx_provider_create(_player_id CHARACTER VARYING, _substation_id CHARACTER VARYING, _rate_denom CHARACTER VARYING, _rate_amount NUMERIC, _access_policy CHARACTER VARYING, _provider_penalty NUMERIC, _consumer_penalty NUMERIC, _capacity_min NUMERIC, _capacity_max NUMERIC, _duration_min NUMERIC, _duration_max NUMERIC);
DROP TABLE IF EXISTS signer.tx CASCADE;
DROP TYPE IF EXISTS structs.signer_tx_status;
DROP TYPE IF EXISTS structs.signer_tx_module;
DROP TYPE IF EXISTS structs.signer_tx_type;

COMMIT;
