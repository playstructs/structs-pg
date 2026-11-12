# Influence grass v1

`influence-grass-20261111` adds complete state-bearing events. Clients do not
invalidate state or fetch an HTTP API when these messages arrive. Scores retain
the contest's configured weights; no scoring rules change in this migration.

## Storage and ingestion

- `influence_player_score_change`: sparse personal component deltas, keyed by
  build, block, player and sector, with a block-height hypertable and a separate
  player/range index. This is deliberately separate from the guild union ledger.
  Multiple same-block events coalesce. Guild moves do not change personal points.
- `influence_grass_dirty`: transaction-local work persisted in a regular table,
  keyed by build/entity. It retains the block-opening guild on the first change.
  Successful raids mark the attacker, prior holder and planet. Transfers mark the
  player and all covered planets, including changes that leave guild totals equal.
- `influence_grass_frame`: durable complete JSON envelopes with monotonic frame
  IDs. The existing influence writer lock serializes allocation and commit order.
  Indexes support ordered drain, scope replay, contest replacement and block
  idempotency. No projection FK: rewind must not remove transport history.
- `influence_grass_delivery`: one acknowledged cursor per NATS destination.

Sync-state finishes the projection then calls `influence_grass_flush` in the
same block transaction. A later failure rolls back scores, personal deltas,
frames and wakeups together. Bulk ingestion flushes each changed block inside
its enclosing transaction; intermediate chart points are retained. A repeated
canonical block enqueues nothing. Empty start/end blocks still announce status.
Quiet intermediate blocks do not resend balances. Snapshot height is the last
explicitly represented height; ordinary consensus heartbeats are not proof that
a separate outbox publisher has delivered a later score change.

Publication of a new build emits replacement snapshots. Initial deployment
backfills personal deltas from exact raid facts and emits a baseline for existing
published contests without rescanning the chain or changing scores. Rebuilds and
rewinds emit explicit zero/absent rows for previously published scopes that have
disappeared. Unpublished builds produce no ordinary live frames.

## Subjects and envelopes

```text
structs.influence.<chain>.<contest>.contest
structs.influence.<chain>.<contest>.scores
structs.influence.<chain>.<contest>.guild.<guild_id>
structs.influence.<chain>.<contest>.player.<player_id>
structs.influence.<chain>.<contest>.planet.<planet_id>
```

Every envelope contains `contract: structs-influence-grass-v1`, `subject`,
`category`, exact string `frame_id`, `previous_frame_id`, `contest_id`, `build_id`,
`height`, `chain_id`, `mode` (`patch` or `replace`), block hash/time, `context`,
and `data`. Replacement and history-segment hash/time can be null; canonical
heights remain exact. Context includes rules, inclusive bounds, scoring mode,
sectors, coverage/projection watermarks, readiness, state and status. Numeric
IDs/heights/counts/points/deltas are strings; sector and multipart indexes are
small JSON integers. IDs with prefixes remain strings.

| Category | Complete data |
|---|---|
| `influence_contest` | Descriptor, rules, bounds, readiness, finality |
| `influence_scores` | Complete guild × sector standings, total-score tiebreakers, ranks, ties/winners, guild/sector history deltas |
| `influence_guild` | Guild sector scores/ranks, changed personal rows with old/new guild IDs, guild history; full roster on replacement |
| `influence_player` | Personal totals and all sectors, current/previous guild, existence, non-additivity flag, personal history |
| `influence_planet` | Scoring sector, latest successful raid, holder and holder guild (nullable), complete guild coverage/support counts, existence |
| `influence_history` | A bounded replacement-history segment, followed by `complete: true` |

A guild frame atomically changes its scores and affected roster entries. A move
appears on the old guild, new guild and stable player scopes. Intermediate moves
inside one block collapse to the opening → final guild transition. Planet scopes
receive the changed claim/coverage attribution as well. Zero scores, null holders,
and `exists:false` are explicit. Full standings replacement removes departed
zero-score guilds; an affected guild scope still receives its removal rows.

Personal scores are not additive guild shares: guild uniqueness is the union of
members' planet wins. Guild frames carry current personal rows; subscribe to a
player scope for that player's historical graph.

## History and replacement

Normal frames include sparse component deltas at their original block height,
not differences between arbitrary delivery times. Sum `unique_delta` and
`claim_delta` over a requested range; add the opening balance for contest
balances. Personal and guild history use separate ledgers. Carry forward the last
balance between sparse changes and preserve exact integer arithmetic.

Replacement snapshots reset the scope's history to a zero balance at contest
start minus one. They announce `history.complete:false`. Subsequent
`influence_history` frames contain at most 512 nonzero guild/player/sector/block
rows each. A terminal segment sets `complete:true`, including an empty segment
when necessary. Stage graph display until complete. The current score snapshot
is already authoritative. This bounds history packet generation even for a long
contest; no single multi-year history array is materialized.

Per-scope predecessor IDs detect gaps; global IDs need not be consecutive within
one scope. Duplicate/older frame IDs are ignored. A new build requires a replace
frame; late old-build frames must not overwrite it. No cross-subscription part
barrier exists: a scoreboard subscriber never waits for player messages.

## Relay, replay and client

The updated structs-grass relay drains committed rows, publishes bounded complete
parts, confirms a NATS flush, then advances its destination checkpoint. A retry
may duplicate frames; it never skips an oversized influence payload. NOTIFY on
`influence_grass` only wakes the relay. Startup and idle polling recover missed
notifications. The existing generic grass/stub behavior is unchanged for other
categories; influence never uses stubs.

Core NATS does not persist offline delivery. The relay therefore serves bounded
replay directly from the retained SQL outbox **over grass**, not an HTTP API.
See `structs-grass/README.md` for the wire protocol. No JetStream configuration is
required. The delivery cursor is not a client acknowledgment and does not control
replay retention. There is intentionally no pruning policy yet: retain frames
until a separately designed snapshot-aware retention migration exists.

`structs-webapp/src/js/framework/InfluenceStream.js` provides an opt-in exact-scope
subscriber, multipart assembler and state store. It subscribes before replaying,
recovers on reconnect/gaps/incomplete multipart messages, verifies SHA-256,
ignores duplicates, and updates scores, roster and sparse history without an HTTP
client. Subscribe to the contest descriptor alongside the score/player/planet scopes a
view needs so readiness and finality are shared without resending every player; it adds no influence UI or
blanket subscription to every player's events. Its default assembly ceiling is
64 MiB per subscriber, configurable on `InfluenceAssembler`. Normal history is
segmented; a current guild replacement contains its full roster.

## Rollout and operation

1. Stop sync-state while applying this paired migration. Deploy schema through
   `influence-grass-20261111`; verification is included in Sqitch. Existing
   contests receive baselines automatically; no manual event rows are needed.
2. Deploy the new sync-state writer. Doctor rejects a missing grass migration.
   Older writers do not call the new flush function, so do not leave them running
   after this migration. Deployment itself does not publish NATS before commit.
3. Build/deploy structs-grass using `go build .` (all package files), then deploy
   the updated docker-structs-grass wrapper. Influence is enabled by default.
   Use a stable, unique `INFLUENCE_DESTINATION` per NATS destination and one active
   relay for each destination. The SQL session lock prevents competing drains.
4. Allow the relay to subscribe to `structs.influence.replay.>` and publish scoped
   influence subjects and reply inboxes. Clients need subscriptions to their
   selected scopes and `_INBOX.>`, and publish permission on the corresponding
   replay request subjects. Treat these scores as the same public gameplay data
   exposed by grass; do not reuse this path for private account data. Require NATS
   `max_payload >= 8192`; no broker storage setting is needed.

The existing `structs_indexer` connection has the required grants. No extra
contest settings or point values are manually configured for event delivery.
Migration rollback refuses to erase a populated outbox. Preserve replay data and
coordinate writer/relay rollback before an operator explicitly clears it.

Monitor outbox max ID minus destination cursor, relay retry logs, oldest pending
frame and total retained bytes. A relay outage grows the outbox rather than
blocking gameplay on network availability. No automatic API refresh is emitted.

## Verification

Run the disposable PG18/Timescale/NATS integration runner in docker-structs-pg:

```sh
python3 tests/test_influence_integration.py --image structs/structs-pg:latest
```

It exercises deploy/verify/revert, populated-schema backfill, real capture and
projection, indexer grants, rollback, same-guild holder changes, guildless/multiple
moves, finalization, rebuild/rewind replacement, bounded player fanout, oversized
multipart replay, relay restart and missed-NOTIFY recovery. Full-schema block
integration additionally covers the real router in streaming and deferred modes.
Run `go test ./...` in each Go package and
`node tools/api/influence-stream.test.mjs` in structs-webapp for client semantics.
