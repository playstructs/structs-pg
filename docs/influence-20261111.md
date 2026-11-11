# Influence: storage and writer contract

Implemented by `influence-schema-20261111` and `influence-projector-20261111`.
Deploy both before the matching docker-structs-pg sync-state writer. This change
does not install webapp endpoints or start a tournament automatically.

## Rules

Default rule 1 awards 100 points per covered **defending planet** per guild and
200 points per last eligible successful raider's planet. Both use the defending
planet's captured sector (127, 999 or 44). Ore and defensive penalties are zero.
Ranges are inclusive `[start_height,end_height]`. Failed raids change neither
component. Select the latest successful raid first: an ineligible success clears
the maintained claim. Eligibility requires different players with nonempty,
different guilds **at the raid event**; later membership does not requalify raids.
Planet completion/abandonment does not remove either component.

Each player carries one qualifying win per planet per contest. Guild coverage is
the union of those wins among its current members. Supporter counts prevent repeat
wins from stacking and preserve coverage when another supporter remains after a
departure. Claims follow their current holder. Guildless players keep their
achievements but credit no guild. A transfer can increase total coverage across
guilds through overlap; global coverage is deliberately not conserved. Personal
win counts are useful activity statistics, not additive shares of a guild score.

## Physical tables

| Table suffix (`structs.influence_`) | Purpose / key |
|---|---|
| `rule_set`, `contest` | Immutable referenced weights/policy and inclusive bounds |
| `raid` | Canonical success facts; unique chain/height/phase/tx/event/attribute |
| `membership_history` | Changed membership plus verified baseline; player/position |
| `source_cursor` | Exact contiguous coverage, processed height and block hash |
| `projection_build`, `published_build` | Replaceable generation and atomic published pointer |
| `member` | Membership at the build watermark; build/player |
| `contest_planet` | Captured scoring sector; build/planet |
| `player_planet_win` | First qualifying in-range win; build/player/planet |
| `guild_planet_win` | Positive supporter count; build/guild/planet |
| `planet_claim` | Latest successful raid and nullable eligible holder; build/planet |
| `player_sector` | Current personal claim count; build/player/sector |
| `guild_sector` | Exact coverage and claim counts; build/guild/sector |
| `score_change` | Signed count deltas with canonical event positions; height hypertable |
| `score_change_1000` | Materialized-only continuous aggregate of signed deltas |
| `rollup_coverage`, `checkpoint` | Verified complete-bucket boundary and sparse guild balances |

Read `influence_standings` for published counts, weighted points, build ID,
projected height, state and sector completeness. This reads small balances instead
of recalculating DISTINCT raid history. Missing guild/sector rows mean zero: an
API should fill these from its contest roster. Sector ranking uses sector points,
then the guild's total across the three sectors; exact ties stay ties and an
all-zero sector has no winner. Heights, counts and numeric scores should be
serialized as exact decimal strings where JavaScript precision could be exceeded.

Mutable projections remain ordinary tables. Transfers use set-based support
mutations and aggregated sector deltas; work scales with that player's distinct
won planets per live contest. No per-planet SQL round trips. History uses
100,000-height chunks and 1,000-height buckets; tune chunk size after observing
actual rows/index bytes. There is no retention or compression policy that could
discard required replay evidence. Do not put DISTINCT or current-membership joins
in continuous aggregates.

## Atomic ingestion

One global influence advisory lock serializes writers, rebuilding and refresh.
This installation has one indexed chain. The block transaction contains all
source facts, projected membership, coverage, claims, balances, history and the
source cursor. A failure rolls them all back, including in a bulk window.

The Go tracker runs before each ordinary event handler, in canonical
PreBlock/BeginBlock/transaction/EndBlock order. A success is paired with exactly
one preceding ore-theft event in the same transaction/message, matching both
player IDs and exact unsigned ore amount, including zero. Intervening events are
allowed. Owner and guild values come from ordered current state at that event,
not an end-of-block activity join. Missing/ambiguous attribution aborts the block.
Ore is retained in the audit JSON but contributes no points. The current protocol
emits one relevant detail per event, so attribute_index is zero; duplicate details
are rejected. Canonical ordering does not depend on surrogate IDs.

The first indexed block seeds membership from the verified previous current-state
boundary. A reconciliation of the already indexed boundary seeds at that height
and starts exact coverage at the next block; it invents no earlier raid facts.
New contests cannot start before `coverage_start`. Empty blocks advance progress.
New/later source facts cannot be inserted through record functions behind the
cursor. Identical raid source replay is idempotent; conflicting facts/hash/time/
message identity fail. Re-ingesting the current block with a different hash fails.

Finalization requires complete ingestion through the end height and known sectors.
Sector 0 is retained explicitly and prevents an official final. A planet changing
sector inside a contest is rejected rather than silently moving history. Register
official contests after sector assignment; do not infer legacy sectors from the
defender's current planet. Later raids and transfers cannot change a final build.

## Contest operations (migration owner)

After the new writer has established coverage:

```sql
SELECT * FROM structs.influence_source_cursor;
-- Replace chain and heights with the actual contest's inclusive bounds.
SELECT structs.influence_create_contest('chain-id',1000000,1100000);
SELECT * FROM structs.influence_standings WHERE contest_id=1;
SELECT r.* FROM structs.influence_published_build p
CROSS JOIN LATERAL structs.influence_reconcile(p.build_id) r WHERE p.contest_id=1;
SELECT structs.influence_rebuild(1);
```

All four reconciliation mismatch counts must be zero. Rebuild replays ordered
facts and membership, reconciles, then publishes a new build in one transaction.
It holds the writer lock: schedule large rebuilds with a maintenance latency
budget. API transactions should pin a build in a repeatable-read snapshot.
Prior generations remain for diagnostics and need an explicit later retention
decision. Eight concurrent/future contests is the admission limit; arbitrary
research windows should be bounded jobs, not unlimited permanent projections.

Referenced rules and contest bounds cannot be updated. To compare weights,
insert another rule with the same supported policy, then create a separate
contest. Facts and stored component counts need no chain rescan. Changes to
eligibility/uniqueness semantics require a new projector implementation.

## Exact history refresh

Run `sync-state influence-refresh` with `DATABASE_URL` for the Timescale view
owner. Each invocation refreshes at most 10,000 completed heights per published
build. Schedule/repeat it as required; no scheduler is enabled by this migration.
It uses a dedicated connection and a session advisory lock across Timescale's
top-level refresh call, then transactionally publishes checkpoints and
`complete_before_height`. Failed/interrupted refresh leaves the old marker valid.
The build ID is also `refreshed_revision`: corrections create a new build, and
rewinds invalidate affected builds and their markers. Do not advance a marker
manually or install a refresh policy and treat its maximum bucket as completeness.

For an inclusive chart range `[L,H]`, use rollups only for entire buckets inside
the range and strictly below its build's marker. Use raw deltas for partial edge
buckets and the unrefreshed tail, with no overlap. Start the cumulative series
from one checkpoint at/before L, or zero at contest start. Fill empty buckets by
carrying balances forward. A sum of deltas over `[L,H]` is a change in an existing
contest, **not** a newly computed unique-score contest over `[L,H]`.

The refresher explicitly requests a complete single batch per call; the Timescale
API otherwise supports committing batches independently. See the official
[refresh API](https://www.tigerdata.com/docs/reference/timescaledb/continuous-aggregates/refresh_continuous_aggregate).

## Recovery and access

The declared ACLs give the webapp read access. The indexer can append source facts and maintain
projections, but cannot UPDATE/DELETE sources or administer contests, published
builds, rules, checkpoints or rollup markers. Functions use invoker rights and
PUBLIC execution is revoked. The migration owner is the trusted recovery role.
Source UPDATEs are also blocked by triggers; DELETEs require the explicit
transaction-local recovery path used by rewind.

**Existing deployment issue:** the packaged image and inspected live database
currently give both `structs_indexer` and `structs_webapp` SUPERUSER. Superusers
bypass all object ACLs and can disable triggers. Verification checks the declared
ACLs and warns about this configuration. Enforcement requires a coordinated
application-role hardening pass (audit existing grants, then use NOSUPERUSER
credentials); this influence migration deliberately does not alter global live
role privileges. The isolated permission tests use non-superuser app roles.

`influence_rewind(chain,height,hash)` is an influence recovery primitive, not a
whole-indexer restore. Stop ingestion, restore **all canonical base tables and
normal sync-state cursors** to the verified target boundary, then invoke it as
owner with the target block hash. It checks `current_block`, removes later
facts, invalidates affected generations and rebuilds their replacements. Resume
complete ordered blocks from target+1. Never run it against today's base tables
just to rewind influence. General sync-state `rewind`/`replay` commands remain
unimplemented; use a coherent snapshot/restore recovery procedure. Isolated
`reprocess-errors` writes are rejected once influence capture exists; dry-run is
still available. `-allow-replay` cannot bypass influence continuity checks.

Sqitch revert refuses a populated source/contest store. Rollback after cutover
requires preserving/restoring the data and matching writer, not dropping the
influence tables under an active indexer. No live database changes were part of
implementation testing.

## Validation

The sibling docker-structs-pg runner `tests/test_influence_integration.py` deploys,
verifies, reverts and redeploys these files on an isolated PostgreSQL18/Timescale
instance with minimal canonical entity tables, then tests Go capture and SQL
projection, real indexer permissions, protected revert, transfers, inclusive ranges,
rebuild/rewind, frozen finals, rollback, invalid attribution and chart refresh.
`internal/sync/influence_integration_test.go` separately exercises the full game
schema through the real block/router/buffer path in streaming and bulk modes.
