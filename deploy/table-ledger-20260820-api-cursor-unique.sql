-- Deploy structs-pg:table-ledger-20260820-api-cursor-unique to pg
--
-- Includes the TimescaleDB time dimension while enforcing the deterministic
-- (time, id) API cursor.

BEGIN;

    CREATE UNIQUE INDEX ledger_time_id_uidx
        ON structs.ledger (time, id);

COMMIT;
