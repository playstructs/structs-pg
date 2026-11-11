# Single-sector influence contests

Deploy `influence-single-sector-20261111` after the original projector. It adds
an immutable `influence_contest.scoring_mode` and preserves the existing
sync-state SQL function signatures. No Go writer change or chain replay is needed.

The existing three/four-argument `influence_create_contest` keeps the default
`planet_sectors` mode: defending-planet sectors determine points, and a recorded
planet in unknown sector 0 prevents finalization. The five-argument form can
explicitly select an all-planets competition:

```sql
SELECT structs.influence_create_contest(
  'structstestnet-111', :start_height, :end_height, 1, 'single_sector'
);
```

In `single_sector` mode, every contest projection and score delta uses sector 0,
which the API/UI should label **All planets**. Immutable raid facts retain their
original sector and payload. This mode does not assert that unknown planets
belong to a particular geographic sector. Raw sectors may become known later
without splitting or changing this contest's scoring area.

The 100-point guild union of members' planet wins, 200-point last eligible
raider claim, event-time cross-guild eligibility and membership transfers are
unchanged. The ending block is inclusive; final projections ignore subsequent
raids and guild transfers. Rebuilds replay the same facts using the contest's
fixed mode. Existing rollups and checkpoints continue to use the projected area.

## Standings and winner selection

`influence_standings` appends `scoring_mode`; `sectors_complete` indicates that
the contest's geography requirements are satisfied, including single-sector
contests. The new read-only `influence_ranked_standings` adds:

| Column | Meaning |
|---|---|
| `overall_points` | Guild score summed across the contest's scoring areas |
| `sector_rank` | Dense rank by sector points, then overall points |
| `tied_for_lead` | Multiple guilds share a positive first-place score after the tiebreaker |
| `is_winner` | Positive first place in a finalized contest with complete sectors |

```sql
SELECT guild,sector,points,overall_points,sector_rank,tied_for_lead,is_winner
FROM structs.influence_ranked_standings
WHERE contest_id = :contest_id
ORDER BY sector,sector_rank,guild;
```

Tied final leaders are co-winners, never arbitrarily ordered by guild ID.
In a single area, the overall-points tiebreaker cannot break a sector-score tie.
An all-zero or empty contest has no winner. Unscored guilds have no standings row;
join the guild roster separately when a UI needs to display them at zero.
The view ranks already maintained guild aggregates; it does not rescan raid
history. Standings and their history must use the same published build snapshot.

Scoring mode is immutable through normal SQL, just like bounds and rule IDs.
The separate, dated rehearsal conversion is a guarded owner migration which
preserves contest identity and checks old/new aggregate equality. It is not a
general mechanism for changing competitions already underway.

Run `python3 tests/test_influence_single_sector.py --image structs/structs-pg:latest`
to exercise real PostgreSQL/Timescale/Sqitch in a disposable container. Coverage
includes migration lifecycle, role access, duplicate guild support, transfers,
changing raw sectors, finalization, replay, ties, zero scores and seed conversion.
