-- Deploy structs-pg:role-structs-indexer to pg

BEGIN;

    GRANT CONNECT ON DATABASE structs to structs_indexer;
    ALTER ROLE structs_indexer SET search_path to cache, structs, public;

    GRANT USAGE on SCHEMA cache to structs_indexer;

    GRANT INSERT, SELECT on cache.events to structs_indexer;
    GRANT INSERT, SELECT on cache.blocks to structs_indexer;
    GRANT INSERT, SELECT on cache.tx_results to structs_indexer;
    GRANT INSERT, SELECT on cache.attributes to structs_indexer;


COMMIT;
