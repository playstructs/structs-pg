-- Deploy structs-pg:table-ledger-20260820-api-read-indexes to pg
--
-- Supports address and action/denom keyset reads. TimescaleDB builds each
-- index one chunk at a time to reduce write blocking during deployment.

    CREATE INDEX ledger_address_time_id_idx
        ON structs.ledger (address, time DESC, id DESC)
        WITH (timescaledb.transaction_per_chunk);

    CREATE INDEX ledger_action_denom_time_id_idx
        ON structs.ledger (action, denom, time DESC, id DESC)
        WITH (timescaledb.transaction_per_chunk);
