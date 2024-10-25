-- Deploy structs-pg:table-ledger to pg

BEGIN;

CREATE TYPE structs.denom AS ENUM ('alpha');

CREATE TYPE structs.ledger_direction AS ENUM ('debit', 'credit');

CREATE TYPE structs.ledger_action AS ENUM ('genesis','received','sent','infused','defused','refined');

CREATE TABLE structs.ledger (
    time TIMESTAMPTZ NOT NULL,
    id BIGSERIAL PRIMARY KEY,
    object_id CHARACTER VARYING,
    address CHARACTER VARYING,
    counterparty CHARACTER VARYING,
    amount BIGINT,
    block_height BIGINT,
    action structs.ledger_action,
    direction structs.ledger_direction,
    denom structs.denom
);



SELECT create_hypertable('structs.ledger', by_range('time'));

COMMIT;
