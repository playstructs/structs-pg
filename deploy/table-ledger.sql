-- Deploy structs-pg:table-ledger to pg

BEGIN;

--CREATE TYPE structs.denom AS ENUM ('alpha','ore','bleep','bloop');

CREATE TYPE structs.ledger_direction AS ENUM ('debit', 'credit');

CREATE TYPE structs.ledger_action AS ENUM ('genesis','received','sent','migrated','infused','defused','mined','refined','seized','forfeited','minted','burned','diverted');

CREATE TABLE structs.ledger (
    time TIMESTAMPTZ DEFAULT NOW(),
    id BIGSERIAL NOT NULL,
    address CHARACTER VARYING,
    counterparty CHARACTER VARYING,
    amount NUMERIC GENERATED ALWAYS AS (structs.UNIT_LEGACY_FORMAT(amount_p, denom)) STORED,
    amount_p NUMERIC, -- real amount
    block_height BIGINT,
    action structs.ledger_action,
    direction structs.ledger_direction,
    denom TEXT
);

SELECT create_hypertable('structs.ledger', by_range('time'));

COMMIT;
