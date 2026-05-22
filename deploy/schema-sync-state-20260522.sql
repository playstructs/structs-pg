-- Deploy structs-pg:schema-sync-state-20260522 to pg
--
-- Adopts the sync_state schema under sqitch. Ports sync-state/sql/bootstrap.sql
-- verbatim — every statement matches what sync-state's runtime Bootstrap()
-- builds today, statement-for-statement. After this change is deployed to
-- prod, sync-state's Bootstrap() reduces to a read-only doctor probe and
-- stops issuing DDL (Phase C).
--
-- Scope (matches the sync-state team's bootstrap.sql delivery):
--   - 1 schema: sync_state
--   - 10 tables: sync_cursor, handler_error_log, block_log,
--                verification_report, raw_blocks, raw_tx_results,
--                raw_events, raw_attributes, unknown_event_log,
--                genesis_log
--   - 1 implicit sequence: handler_error_log_id_seq (from BIGSERIAL)
--   - 7 primary-key constraints (5 single-column, 2 composite)
--   - 6 secondary indexes (3 partial, 3 plain)
--   - 1 forward-migration ALTER (severity column on handler_error_log;
--     no-op on fresh sqitch deploys since the CREATE above already has
--     the column — kept here for source-of-truth parity with the
--     sync-state delivery file)
--
-- Out of scope per sync-state team:
--   - No hypertables (none of the sync_state tables are hypertables).
--   - No grants. Grants on sync_state.* belong in role-structs-* files
--     if/when consumers other than sync-state need access; sync-state
--     itself owns the schema as its own DB user.
--   - No functions, triggers, comments.
--
-- All statements use IF NOT EXISTS / ADD COLUMN IF NOT EXISTS so this
-- change is safe to apply against an environment where sync-state's
-- runtime Bootstrap() has already created the tables (i.e. live prod
-- during the cutover window).

BEGIN;

    CREATE SCHEMA IF NOT EXISTS sync_state;

    -- sync_state.sync_cursor
    --
    -- One row per chain_id. The block-by-block ingest reads/writes this
    -- row on every commit (in bulk mode: once per window). Canonical
    -- "what height have we processed through?" pointer.
    CREATE TABLE IF NOT EXISTS sync_state.sync_cursor (
        chain_id          VARCHAR PRIMARY KEY,
        last_height       BIGINT NOT NULL,
        last_block_hash   VARCHAR,
        last_block_time   TIMESTAMPTZ,
        status            TEXT,
        lag_blocks        BIGINT,
        tip_height        BIGINT,
        updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    -- sync_state.handler_error_log
    --
    -- Append-only log of every per-event handler error. Operators query
    -- this to find handler bugs after a bulk replay. severity is one of
    -- {'error','warn','info'} — see sync-state internal/events/handler.go
    -- for the policy.
    CREATE TABLE IF NOT EXISTS sync_state.handler_error_log (
        id                BIGSERIAL PRIMARY KEY,
        chain_id          VARCHAR NOT NULL,
        height            BIGINT NOT NULL,
        tx_index          INT,
        msg_index         INT,
        event_index       INT,
        composite_key     VARCHAR NOT NULL,
        payload           JSONB,
        error             TEXT NOT NULL,
        stack             TEXT,
        severity          TEXT NOT NULL DEFAULT 'error',
        created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        resolved_at       TIMESTAMPTZ,
        resolved_by       TEXT
    );

    -- Forward-migration for pre-severity deployments. No-op on fresh
    -- sqitch deploys (the CREATE above already has the column). Kept
    -- verbatim from bootstrap.sql for source-of-truth parity.
    ALTER TABLE sync_state.handler_error_log
        ADD COLUMN IF NOT EXISTS severity TEXT NOT NULL DEFAULT 'error';

    CREATE INDEX IF NOT EXISTS handler_error_log_unresolved_idx
        ON sync_state.handler_error_log (chain_id, composite_key, created_at)
        WHERE resolved_at IS NULL;

    CREATE INDEX IF NOT EXISTS handler_error_log_severity_unresolved_idx
        ON sync_state.handler_error_log (chain_id, severity)
        WHERE resolved_at IS NULL;

    -- sync_state.block_log
    --
    -- One row per ingested block. num_handler_errors lets operators see
    -- the error density without aggregating handler_error_log.
    CREATE TABLE IF NOT EXISTS sync_state.block_log (
        chain_id            VARCHAR NOT NULL,
        height              BIGINT NOT NULL,
        block_hash          VARCHAR NOT NULL,
        block_time          TIMESTAMPTZ NOT NULL,
        num_txs             INT NOT NULL,
        num_events          INT NOT NULL,
        num_handler_errors  INT NOT NULL DEFAULT 0,
        ingested_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (chain_id, height)
    );

    -- sync_state.verification_report
    --
    -- Per-run output of `sync-state verify`. status ∈
    -- {'pass','warn','info','fail','skip'}; one row per
    -- (run_id, scope[, height, composite_key]). Append-only; runs
    -- distinguished by run_id (UUID).
    CREATE TABLE IF NOT EXISTS sync_state.verification_report (
        run_id        UUID NOT NULL,
        scope         TEXT NOT NULL,
        height        BIGINT,
        composite_key TEXT,
        expected      JSONB,
        actual        JSONB,
        status        TEXT NOT NULL,
        created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    -- sync_state.raw_* — raw mirror tables
    --
    -- Always CREATED, written only when SYNC_STATE_MIRROR_RAW=true (or
    -- `-mirror-raw=true`). The cache.* compatibility views created by
    -- retire-cache-20260522 read from these tables; running without
    -- mirror-raw means cache.* views show only rows ingested while
    -- mirror-raw was on.
    CREATE TABLE IF NOT EXISTS sync_state.raw_blocks (
        chain_id     VARCHAR NOT NULL,
        height       BIGINT NOT NULL,
        block_hash   VARCHAR NOT NULL,
        block_time   TIMESTAMPTZ NOT NULL,
        proposer     VARCHAR,
        num_txs      INT NOT NULL,
        ingested_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (chain_id, height)
    );

    CREATE TABLE IF NOT EXISTS sync_state.raw_tx_results (
        chain_id     VARCHAR NOT NULL,
        height       BIGINT NOT NULL,
        tx_index     INT NOT NULL,
        tx_hash      VARCHAR NOT NULL,
        code         INT NOT NULL,
        gas_used     BIGINT,
        log          TEXT,
        raw_json     JSONB NOT NULL,
        ingested_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (chain_id, height, tx_index)
    );

    -- raw_events / raw_attributes have NO primary key by design — the
    -- chain can emit duplicate (composite_key, value) pairs in a single
    -- block and we keep every emission, ordered by event_index. The
    -- compatibility views in retire-cache-20260522 synthesize a
    -- deterministic surrogate id from (height, tx_index, event_index).
    CREATE TABLE IF NOT EXISTS sync_state.raw_events (
        chain_id     VARCHAR NOT NULL,
        height       BIGINT NOT NULL,
        tx_index     INT,
        event_index  INT NOT NULL,
        event_type   VARCHAR NOT NULL,
        ingested_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS raw_events_height_idx
        ON sync_state.raw_events (chain_id, height);

    CREATE TABLE IF NOT EXISTS sync_state.raw_attributes (
        chain_id      VARCHAR NOT NULL,
        height        BIGINT NOT NULL,
        tx_index      INT,
        event_index   INT NOT NULL,
        key           VARCHAR NOT NULL,
        value         TEXT,
        composite_key VARCHAR NOT NULL,
        ingested_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS raw_attributes_height_idx
        ON sync_state.raw_attributes (chain_id, height);
    CREATE INDEX IF NOT EXISTS raw_attributes_composite_key_idx
        ON sync_state.raw_attributes (composite_key, height);

    -- sync_state.unknown_event_log
    --
    -- One row per distinct composite_key (event_type.attribute_key) that
    -- the router did NOT have a registered handler for. Coverage
    -- dashboard for "are we processing every attribute the chain emits?"
    --
    -- count / first_seen_height / last_seen_height accumulate
    -- monotonically across ingest runs (UPSERT with GREATEST / LEAST).
    -- last_payload holds the most-recent raw attribute value as a JSON
    -- literal so operators can pivot directly into sync_state.raw_attributes
    -- for full samples.
    CREATE TABLE IF NOT EXISTS sync_state.unknown_event_log (
        chain_id           VARCHAR NOT NULL,
        composite_key      VARCHAR NOT NULL,
        count              BIGINT  NOT NULL DEFAULT 0,
        first_seen_height  BIGINT  NOT NULL,
        last_seen_height   BIGINT  NOT NULL,
        first_seen_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        last_seen_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        last_payload       JSONB,
        PRIMARY KEY (chain_id, composite_key)
    );
    CREATE INDEX IF NOT EXISTS unknown_event_log_count_idx
        ON sync_state.unknown_event_log (chain_id, count DESC);

    -- sync_state.genesis_log
    --
    -- One row per (chain_id) that has had its genesis JSON applied to
    -- structs.ledger (action='genesis'). Idempotency guard for
    -- `sync-state init-genesis`: ingest auto-applies on first start
    -- from height 1 when this row is missing.
    --
    -- source is "rpc:<url>" or "file:<path>". sha256 is over the raw
    -- genesis JSON bytes (pre-parse) so a reapply against a tampered
    -- genesis is detectable. rows_per_section is a small JSONB
    -- ({"bank":138,"delegations":40,...}) the verify runner can surface
    -- without re-parsing genesis.
    --
    -- Cross-check invariant (enforced by `sync-state verify` and by
    -- retire-cache.sql's step 7g probe):
    --   total_rows MUST equal COUNT(*) FROM structs.ledger WHERE action='genesis'
    CREATE TABLE IF NOT EXISTS sync_state.genesis_log (
        chain_id           VARCHAR PRIMARY KEY,
        applied_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        source             TEXT NOT NULL,
        genesis_time       TIMESTAMPTZ NOT NULL,
        sha256             VARCHAR(64) NOT NULL,
        rows_per_section   JSONB NOT NULL,
        total_rows         BIGINT NOT NULL
    );

COMMIT;
