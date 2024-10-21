-- Deploy structs-pg:schema-structs to pg

BEGIN;

    CREATE SCHEMA structs;

    CREATE EXTENSION IF NOT EXISTS timescaledb;

COMMIT;
