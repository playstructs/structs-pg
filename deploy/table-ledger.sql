-- Deploy structs-pg:table-ledger to pg

BEGIN;

--CREATE TYPE structs.denom AS ENUM ('alpha','ore','bleep','bloop');

CREATE TYPE structs.ledger_direction AS ENUM ('debit', 'credit');

CREATE TYPE structs.ledger_action AS ENUM ('genesis','received','sent','migrated','infused','defused','mined','refined','seized','forfeited','minted','burned');

CREATE TABLE structs.ledger (
    time TIMESTAMPTZ DEFAULT NOW(),
    id BIGSERIAL NOT NULL,
    object_id CHARACTER VARYING,
    address CHARACTER VARYING,
    counterparty CHARACTER VARYING,
    amount NUMERIC,
    block_height BIGINT,
    action structs.ledger_action,
    direction structs.ledger_direction,
    denom TEXT
);

SELECT create_hypertable('structs.ledger', by_range('time'));

COMMIT;
