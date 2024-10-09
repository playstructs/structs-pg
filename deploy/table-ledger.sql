-- Deploy structs-pg:table-ledger to pg

BEGIN;

CREATE TYPE structs.denom AS ENUM ('alpha');

CREATE TYPE structs.ledger_direction AS ENUM ('debit', 'credit');

CREATE TYPE structs.ledger_action AS ENUM ('genesis','transfer in','transfer out','infused','defused','refined');

CREATE UNLOGGED TABLE structs.ledger (
    id BIGINT PRIMARY KEY,
    address CHARACTER VARYING,
    counterparty CHARACTER VARYING,
    amount BIGINT,
    block_height BIGINT,
    created_at TIMESTAMPTZ NOT NULL,
    action structs.ledger_action,
    direction structs.ledger_direction,
    denom structs.denom
);



COMMIT;
