# Official three-sector contest and rehearsal reset

`influence-official-contest-20261120` is part of the normal `sqitch.plan`.
It deliberately deletes **all old contest test data**, resets contest numbering,
and installs the same official contest on every guild database that deploys it.
It does **not** delete chain history.

| Setting | Official value |
| --- | --- |
| Contest ID | **1** |
| Chain | `structstestnet-111` |
| Inclusive start block | **3,743,186** |
| Inclusive last block | **3,957,791** |
| Intended start | November 24, 2026, 11 a.m. ET / 16:00 UTC |
| Intended end | December 8, 2026, 11 a.m. ET / 16:00 UTC |
| Mode | `planet_sectors`: **44, 127, 999** |
| Rule 1 | **100** per distinct guild/planet; **200** per maintained claim |

The supplied block heights are authoritative. Both endpoint blocks count; the
wall-clock times are the intended schedule, dependent on actual chain timing.
Points belong to the defending planet's sector. Guild contributions follow
players' membership through the last block. Each sector has a winner; total
guild points break sector-score ties, and remaining positive ties share the win.
No ore points or defensive penalties are enabled.

## What is cleared

The migration removes every previous contest and rule configuration, published
and unpublished build, contest roster, planet coverage/claim, guild/player score
projection, guild/player score-change history, checkpoint, rollup watermark,
materialized influence aggregate, dirty notification row and old outbox payload.
It reseeds rule 1 and contest 1; the next allocated contest ID is 2.

`influence_raid`, `influence_membership_history`, `influence_source_cursor` and
their source identities/sequences are preserved unchanged. All other chain,
player, guild, planet, ledger and activity history is untouched. These are
canonical source records, not contest scores. Rebuilding the official contest
filters raids to its own inclusive window, so earlier test-contest wins/claims
cannot carry over. Its roster is reconstructed from canonical membership.

Internal build IDs and Grass frame IDs **continue increasing**; resetting them
would make clients ignore new state or accept stale messages. Grass delivery
checkpoints also remain intact because running relays cache them in memory.
Only contest/rule numbering restarts.

## Grass cutover

Old score payloads are deleted. Fresh `mode: replace` control messages clear
previously published scopes: `context.status: removed`, `context.exists: false`,
and `replacement_contest_id: "1"` / `replacement_chain_id: "structstestnet-111"`.
Scores and rosters are empty, personal points are zero, planets have no holder
or coverage, and histories are empty and complete. These control messages retain
only routing/predecessor identity, not test scores, rules, dates or rosters.
They use the existing subjects, categories and multipart delivery format.

Contest 1 then receives the normal full replacement snapshots for the official
definition, with a still newer build ID. Old planets/players/guilds absent from
the new build receive explicit empty/absent replacements. Clients should remove
retired contests on `context.exists: false` and apply the subsequent official
replacement normally; no HTTP refresh is needed for this transition. Buffered
old frames are rejected by the existing monotonic generation/frame checks.

## Deployment and ingestion

Deploy through the normal structs-pg schema release and `sqitch deploy --verify`.
The reset, cache cleanup, definition and outbox cutover are one transaction
serialized with influence ingestion. A 10-second lock timeout makes a busy
deployment fail cleanly for retry. The API context table is locked first to
drain in-flight snapshots before its projections are replaced.

The old November 17 bootstrap trigger is removed, so it cannot recreate a test
contest. The replacement deferred trigger initializes official contest 1 after
the writer's complete first block/baseline, including on fresh installs. It is
owner-only and requires no sync-state or Grass binary change. With existing
source coverage, the migration publishes immediately. Late deployment replays
captured official-window events through the local source height, capped at end.
It never adjusts the supplied heights to suit an individual guild.

If source capture began after 3,743,186, configuration is installed but results
remain unpublished until exact source coverage is recovered. Missing chain
facts cannot be turned into valid contest scores. An installation on another
chain stores the definition without publishing results for this testnet.

Truncating the raw influence hypertable alone leaves old materialized rows.
The migration clears those chunks using Timescale's public `drop_chunks` API.
It resolves the extension schema from `pg_extension`; the API may live in
`structs` (production) or `public`, and is not hard-coded to either namespace.
The aggregate's identity, definition, grants, indexes and any operator-added
policies remain intact. Cleared coverage markers keep API history on the exact
raw path until the new official data has been refreshed and marked available.

The earlier rehearsal verification scripts recognize this explicit replacement,
so full-plan verification still works. Previously deployed migration bodies and
Sqitch registry entries are retained. Reverting is intentionally refused: deleted
test data cannot be restored by a schema rollback. Use a forward migration for
any subsequent correction. The normal Sqitch registry ensures the reset runs
once; later `sqitch deploy` calls do not erase official scores.

## Validation

```sh
python3 tests/test_influence_official_contest.py --image structs/structs-pg:latest
python3 tests/test_influence_official_contest.py --image structs/structs-pg:latest --timescale-schema public
```

The runner uses an isolated PostgreSQL/Timescale container and real Sqitch,
including populated rehearsal history/aggregates and preservation of canonical
history. It never connects to a guild database.

If deployment of commit `861902a` failed with `public.drop_chunks ... does not
exist`, the migration transaction rolled back and Sqitch did not record it as
deployed. Publish this correction and retry normal `sqitch deploy --verify`.
No manual deletion, reseeding, revert or Sqitch registry repair is needed.

```sql
SELECT c.*, b.build_id, b.projected_height, b.state
FROM structs.influence_contest c
LEFT JOIN structs.influence_published_build p USING (contest_id)
LEFT JOIN structs.influence_projection_build b USING (build_id)
WHERE c.contest_id = 1;

SELECT r.* FROM structs.influence_published_build p
CROSS JOIN LATERAL structs.influence_reconcile(p.build_id) r
WHERE p.contest_id = 1;
```
