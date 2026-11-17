# November 17–18 three-sector contest

`influence-contest-20261117` is in the **normal `sqitch.plan`**. Every guild
deploying this schema receives the same immutable contest ID **2**, even if it
never installed the optional contest 1 rehearsal. No optional plan, local insert,
wall-clock calculation, or sync-state binary change is required.

| Setting | Value |
| --- | --- |
| Chain | `structstestnet-111` |
| Contest ID | `2` |
| Inclusive start | `3633541` |
| Inclusive end | `3649817` |
| Scoring mode | `planet_sectors` |
| Sectors | `44`, `127`, `999` |
| Rule | `1`: 100 per unique guild/planet, 200 per maintained claim |
| Estimated start (Toronto) | November 17, 2026, 10:27:33 a.m. EST |
| Estimated end (Toronto) | November 18, 2026, 10:27:31 a.m. EST |

These times use block 3633445 at `2026-11-17T15:19:03.382818Z` and the preceding
5,000 blocks averaging **5.3083316126 seconds/block**. The start targets ten
minutes after the request; the end is 16,276 block intervals later (approximately
24 hours). Both endpoint blocks count, giving 16,277 eligible heights. Chain
timing can drift; fixed heights, not the time estimates, decide eligibility.

The local source check found 28,665 planets in sector 44, 28,773 in 127 and
28,824 in 999, with none unassigned. Points use the defending planet's sector.
Each sector has a winner; total guild points across sectors break sector-score
ties. Remaining exact positive ties share a win. Guild changes carry player
contributions until the inclusive end, then results freeze. Ore and defensive
penalties are not scored. Contest 1 and its final scores are unchanged.

## Deployment and coverage

Publish this structs-pg revision through the normal schema distribution path.
Guild auto-migrators following that revision run `sqitch deploy --verify` and
install the contest. Merely editing a local checkout does not distribute it.

If exact influence capture already covers the start height, deployment rebuilds
and atomically publishes contest 2 immediately, including its normal grass
replacement frames. Deployment during or after the contest replays the stored
facts through the local source cursor, capped at the end; it never moves bounds.

A database without an influence source cursor receives the definition first.
A deferred source-cursor trigger publishes it after the writer has finished its
first complete baseline/block transaction, provided `coverage_start <= 3633541`.
The existing writer then projects subsequent blocks and emits normal grass
updates. The owner-only trigger grants no new contest-administration capability
to webapp or indexer roles. Published contests need no repeated rebuild.

If capture began **after** block 3633541, the definition remains unpublished:
missing history cannot produce valid scores. Recover exact historical source
coverage before expecting this guild's API to serve contest results. A normal
schema install still succeeds on fresh databases and other chains.

A different pre-existing contest with ID 2, or this window under another ID,
causes a clear migration error instead of silently replacing or renumbering it.
The identity sequence advances transactionally past reserved IDs. Reverting this
migration is intentionally refused: distributed contest identities, published
grass messages and scores are durable. Corrections require a forward migration.

Check the local publication and integrity with:

```sql
SELECT c.*, b.build_id, b.projected_height, b.state
FROM structs.influence_contest c
LEFT JOIN structs.influence_published_build p USING (contest_id)
LEFT JOIN structs.influence_projection_build b USING (build_id)
WHERE c.contest_id = 2;

SELECT r.* FROM structs.influence_published_build p
CROSS JOIN LATERAL structs.influence_reconcile(p.build_id) r
WHERE p.contest_id = 2;
```

The isolated migration test uses an already installed PG/Timescale image and
never connects to a guild database:

```sh
python3 tests/test_influence_contest_20261117.py --image structs/structs-pg:latest
```
