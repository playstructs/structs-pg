-- Deploy structs-pg:table-struct-20260810-idx-owner to pg
--
-- getStructsByPlayerId filters on struct.owner. Without an index the query
-- seq-scans the whole struct table (~80k rows / 1600 pages) for every map load.

BEGIN;

    CREATE INDEX struct_owner_idx ON structs.struct (owner);

COMMIT;
