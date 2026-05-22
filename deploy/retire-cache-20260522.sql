-- Deploy structs-pg:retire-cache-20260522 to pg
--
-- Retires the cache.* event-sink schema. All chain-event ingestion is
-- now owned by the sync-state Go binary, which writes directly into
-- structs.* and sync_state.raw_*.
--
-- What this change does:
--   1. Drops seven cache-era triggers from structs.* tables.
--   2. Drops two structs-owned trigger functions whose only callers
--      were those triggers.
--   3. DROP SCHEMA cache CASCADE — removes the entire legacy event-sink
--      schema (tables, indexes, functions, the cache.handle_event_*
--      router, the cache.event_handlers registry, queue/tmp_json
--      scratch, every cache-side trigger function).
--   4. Recreates cache.* as four SELECT-only compatibility views over
--      sync_state.raw_*, preserving the rowid / block_id / tx_id /
--      event_id JOIN semantics the webapp still depends on. Surrogate
--      ids are derived deterministically from natural keys (height,
--      tx_index, event_index) — see view bodies for the formulas.
--      Range budgets: tx_index < 10^4, event_index < 10^4 (asserted by
--      sync-state's operator script before live cutover).
--   5. Re-grants the four cache.* SELECT grants the webapp role held
--      on the original tables.
--
-- Intentionally NOT dropped (defense-in-depth — these structs-native
-- triggers continue to fire after cutover; sync-state's Go handlers
-- are idempotent against them via IS DISTINCT FROM guards):
--   structs.player_address_cascade           ON structs.player
--   structs.player_address_notify            ON structs.player_address
--   structs.player_address_pending_merge     ON structs.player_address
-- The cascade trigger also seeds structs.player_address on player
-- INSERT in edge cases where sync-state's EventAddress /
-- EventAddressAssociation seed event is missing. Keeping the trigger
-- in place guards against direct UPDATEs to structs.player from
-- outside sync-state (DBA console, future tools, legacy backfills).
--
-- Caveats:
--   - cache.tx_results.tx_result BYTEA is permanently NULL in the view.
--     sync-state never captured the raw protobuf wire bytes; any
--     consumer that needs them must migrate to
--     sync_state.raw_tx_results.raw_json (full event JSON) before
--     this change is applied.
--   - cache.queue, cache.attributes_tmp, cache.tmp_json have no
--     compatibility view. No producer was identified during the
--     cache-retirement audit. A hidden consumer hits "relation does
--     not exist" immediately rather than silently degrading.
--
-- The trigger-absence guard (which would otherwise live in a
-- sync_state.retired_triggers table) is in verify/retire-cache-20260522.sql.
-- sync-state's doctor probe keeps a matching hardcoded list — see
-- the comment in sync-state/internal/doctor/doctor.go.
--
-- All DROP IF EXISTS / CREATE OR REPLACE so this change is idempotent
-- against environments where sync-state's operator script
-- (sync-state/sql/retire-cache.sql) has already run.

BEGIN;

    -- 1. Drop cache-era triggers on structs.* tables.
    DROP TRIGGER IF EXISTS update_address_guild_id          ON structs.player;
    DROP TRIGGER IF EXISTS name_planet                       ON structs.planet;
    DROP TRIGGER IF EXISTS add_infusion_ledger_entry         ON structs.infusion;
    DROP TRIGGER IF EXISTS planet_activity_struct_movement   ON structs.struct;
    DROP TRIGGER IF EXISTS planet_activity_fleet_move        ON structs.fleet;
    DROP TRIGGER IF EXISTS planet_activity_raid_status       ON structs.planet_raid;
    DROP TRIGGER IF EXISTS planet_activity_struct_attribute  ON structs.struct_attribute;

    -- 2. Drop the structs-owned trigger functions whose only callers
    --    were the triggers dropped above. Cache-side trigger functions
    --    (cache.add_queue, cache.transfer_ledger_entry, ...) ride the
    --    DROP SCHEMA cache CASCADE below.
    DROP FUNCTION IF EXISTS structs.NAME_PLANET();
    DROP FUNCTION IF EXISTS structs.INFUSION_LEDGER_ENTRY();

    -- 3. Drop the entire cache schema and everything it owns.
    DROP SCHEMA IF EXISTS cache CASCADE;

    -- 4. Recreate cache as a SELECT-only compatibility layer over
    --    sync_state.raw_*. The webapp's cache.blocks / cache.tx_results /
    --    cache.events / cache.attributes queries continue to work
    --    without code changes.
    CREATE SCHEMA cache;

    COMMENT ON SCHEMA cache IS
        'Compatibility layer over sync_state.raw_*. Read-only views; '
        'surrogate rowid / event_id columns are derived from natural '
        'keys (height, tx_index, event_index). The webapp should '
        'migrate to sync_state.raw_* directly; this schema is a '
        'transitional shim.';

    -- block_id = height. Stable across sessions for a given chain.
    CREATE OR REPLACE VIEW cache.blocks AS
    SELECT
        rb.height       AS rowid,
        rb.height       AS height,
        rb.chain_id     AS chain_id,
        rb.block_time   AS created_at
      FROM sync_state.raw_blocks rb;

    COMMENT ON VIEW cache.blocks IS
        'Surrogate rowid = height. Stable across sessions for a given chain.';

    -- rowid = height * 10^4 + (tx_index + 1).
    -- tx_result is permanently NULL — sync-state never captured the
    -- raw protobuf.
    CREATE OR REPLACE VIEW cache.tx_results AS
    SELECT
        (rtr.height * 10000 + (rtr.tx_index + 1))::BIGINT  AS rowid,
        rtr.height                                          AS block_id,
        rtr.tx_index                                        AS index,
        rtr.ingested_at                                     AS created_at,
        rtr.tx_hash                                         AS tx_hash,
        NULL::BYTEA                                         AS tx_result
      FROM sync_state.raw_tx_results rtr;

    COMMENT ON VIEW cache.tx_results IS
        'tx_result is permanently NULL (raw protobuf not captured by '
        'sync-state). Surrogate rowid = height*10^4 + (tx_index+1); '
        'block_id matches cache.blocks.rowid.';

    -- rowid = height * 10^8 + (COALESCE(tx_index, -1) + 1) * 10^4 + event_index.
    -- block_id = height; tx_id matches cache.tx_results.rowid (NULL for
    -- block-level events).
    CREATE OR REPLACE VIEW cache.events AS
    SELECT
        (re.height::BIGINT * 100000000
            + (COALESCE(re.tx_index, -1) + 1)::BIGINT * 10000
            + re.event_index::BIGINT)                       AS rowid,
        re.height                                           AS block_id,
        CASE WHEN re.tx_index IS NULL THEN NULL
             ELSE (re.height * 10000 + (re.tx_index + 1))::BIGINT
        END                                                 AS tx_id,
        re.event_type                                       AS type
      FROM sync_state.raw_events re;

    COMMENT ON VIEW cache.events IS
        'block_id matches cache.blocks.rowid; tx_id matches '
        'cache.tx_results.rowid (NULL for block-level events). '
        'Surrogate rowid = height*10^8 + (COALESCE(tx_index,-1)+1)*10^4 + event_index.';

    -- event_id = same formula as cache.events.rowid above.
    CREATE OR REPLACE VIEW cache.attributes AS
    SELECT
        (ra.height::BIGINT * 100000000
            + (COALESCE(ra.tx_index, -1) + 1)::BIGINT * 10000
            + ra.event_index::BIGINT)                       AS event_id,
        ra.key                                              AS key,
        ra.composite_key                                    AS composite_key,
        ra.value                                            AS value
      FROM sync_state.raw_attributes ra;

    COMMENT ON VIEW cache.attributes IS
        'event_id matches cache.events.rowid. Use natural keys (height, '
        'tx_index, event_index, key) for new code — surrogate event_id '
        'is convenience only.';

    -- 5. Re-grant cache.* SELECT to the webapp role on the new views.
    DO $$
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'structs_webapp') THEN
            GRANT USAGE  ON SCHEMA cache         TO structs_webapp;
            GRANT SELECT ON cache.blocks         TO structs_webapp;
            GRANT SELECT ON cache.tx_results     TO structs_webapp;
            GRANT SELECT ON cache.events         TO structs_webapp;
            GRANT SELECT ON cache.attributes     TO structs_webapp;
        END IF;
    END $$;

COMMIT;
