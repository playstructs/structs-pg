-- Deploy structs-pg:cache-system to pg

BEGIN;

/*
  This file defines the database schema for the PostgresQL ("psql") event sink
  implementation in Tendermint. The operator must create a database and install
  this schema before using the database to index events.
 */

CREATE SCHEMA cache;

-- The blocks table records metadata about each block.
-- The block record does not include its events or transactions (see tx_results).
CREATE TABLE cache.blocks (
  rowid      BIGSERIAL PRIMARY KEY,

  height     BIGINT NOT NULL,
  chain_id   VARCHAR NOT NULL,

  -- When this block header was logged into the sink, in UTC.
  created_at TIMESTAMPTZ NOT NULL,

  UNIQUE (height, chain_id)
);

-- Index blocks by height and chain, since we need to resolve block IDs when
-- indexing transaction records and transaction events.
CREATE INDEX idx_blocks_height_chain ON cache.blocks(height, chain_id);

-- The tx_results table records metadata about transaction results.  Note that
-- the events from a transaction are stored separately.
CREATE TABLE cache.tx_results (
  rowid BIGSERIAL PRIMARY KEY,

  -- The block to which this transaction belongs.
  block_id BIGINT NOT NULL,
  -- The sequential index of the transaction within the block.
  index INTEGER NOT NULL,
  -- When this result record was logged into the sink, in UTC.
  created_at TIMESTAMPTZ NOT NULL,
  -- The hex-encoded hash of the transaction.
  tx_hash VARCHAR NOT NULL,
  -- The protobuf wire encoding of the TxResult message.
  tx_result BYTEA NOT NULL,

  UNIQUE (block_id, index)
);

--CREATE OR REPLACE VIEW cache.tx_results AS SELECT * FROM cache.tx_results_tbl;
--CREATE OR REPLACE RULE block_tx_results AS ON INSERT to cache.tx_results DO INSTEAD NOTHING;


-- The events table records events. All events (both block and transaction) are
-- associated with a block ID; transaction events also have a transaction ID.
CREATE TABLE cache.events (
  rowid BIGSERIAL PRIMARY KEY,

  -- The block and transaction this event belongs to.
  -- If tx_id is NULL, this is a block event.
  block_id BIGINT NOT NULL,
  tx_id    BIGINT NULL,

  -- The application-defined type label for the event.
  type VARCHAR NOT NULL
);

-- The attributes table records event attributes.
CREATE TABLE cache.attributes_tbl (
   event_id      BIGINT NOT NULL,
   key           VARCHAR NOT NULL, -- bare key
   composite_key VARCHAR NOT NULL, -- composed type.key
   value         VARCHAR NULL,
   UNIQUE (event_id, key)
);

CREATE OR REPLACE VIEW cache.attributes AS SELECT * FROM cache.attributes_tbl;

CREATE TABLE cache.queue (
	channel CHARACTER VARYING, 
	id CHARACTER VARYING,
	CONSTRAINT queue_unique UNIQUE (channel, id)
); 

CREATE OR REPLACE FUNCTION cache.ADD_QUEUE()
  RETURNS trigger AS
$BODY$
BEGIN
	IF NEW.type = 'structs.structs.EventCacheInvalidation' THEN
		INSERT INTO cache.queue (channel, id) values (
	            (SELECT attributes.value FROM cache.attributes WHERE attributes.composite_key = 'structs.structs.EventCacheInvalidation.object_type' and attributes.event_id = NEW.rowid),
	            (SELECT attributes.value FROM cache.attributes WHERE attributes.composite_key = 'structs.structs.EventCacheInvalidation.object_id' and attributes.event_id = NEW.rowid)
	    ) ON CONFLICT ON CONSTRAINT queue_unique DO NOTHING;
	END IF;
	RETURN NEW; 
END
$BODY$
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER
  COST 100;

CREATE TRIGGER ADD_QUEUE AFTER INSERT ON cache.events
 FOR EACH ROW EXECUTE PROCEDURE cache.ADD_QUEUE();

--CREATE TRIGGER ADD_QUEUE INSTEAD OF INSERT ON cache.attributes
--    FOR EACH ROW EXECUTE PROCEDURE cache.ADD_QUEUE();

GRANT CONNECT ON DATABASE structs to structs_indexer;
GRANT USAGE on SCHEMA cache to structs_indexer;
GRANT INSERT, SELECT on cache.events to structs_indexer;
GRANT INSERT, SELECT on cache.blocks to structs_indexer;
GRANT INSERT, SELECT on cache.tx_results to structs_indexer;
GRANT INSERT, SELECT on cache.attributes to structs_indexer;

ALTER ROLE structs_indexer SET search_path to cache, public, structs;

COMMIT;

