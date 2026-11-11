# Local test contest: November 11–16, 2026

This optional data migration registers one 100/200 test contest on
`structstestnet-111`. It is in **sqitch.test-contests.plan**, a separate Sqitch
project requiring the main project's influence projector and single-sector migrations. Regular
schema deployments therefore do not require an already running influence writer
or create a dated test contest on fresh installations.

Deploy the ordinary schema and matching sync-state writer first. After at least
one influence block commits, run from the structs-pg checkout as the DB owner:

```sh
sqitch --plan-file sqitch.test-contests.plan deploy --verify --target YOUR_SQITCH_TARGET
```

The command checks that influence, the canonical state and the normal sync cursor
agree on chain, height and block hash. It registers the contest through
`influence_create_contest`, including its initial rebuilt/published scores.

| Setting | Value |
|---|---|
| Chain | `structstestnet-111` |
| Rule | 1: 100 points for guild planet coverage, 200 for a maintained claim |
| Scoring mode | `single_sector`: all planets compete in one scoring area |
| Requested start | 3,545,535 |
| Effective start | Later of requested start and the first exact influence-covered block |
| Inclusive end | 3,626,388 |
| Approximate end time | Monday, November 16, 2026, 3:00 p.m. America/Toronto / 20:00 UTC |

The estimate uses block 3,545,534 at 2026-11-11T20:21:25.639412219Z and the
previous 10,000 blocks' mean interval of 5.3270449192 seconds. Observed means for
1,000 and 30,000 blocks were 5.319859136 and 5.322136059966667 seconds. The block
limit is authoritative; the actual ending clock time will drift with block timing.
Registration is refused once the ending block has been reached.

No pre-cutover membership or raid history is invented. A delayed deployment
therefore shortens the test window. No guild roster, manual sector assignment or
automatic refresh scheduler is added. Sampled active/completed planets on the
current node omit the sector field, so the second optional migration explicitly
converts this rehearsal into one all-planets scoring area. This produces a valid
combined winner, not three geographic winners. Raw raid sectors remain untouched.
The contest ID, block bounds, weights and existing scores are preserved. Conversion
requires an unfinished contest whose recorded raids all have unknown sector 0;
it rebuilds and checks the scores before atomically publishing the new build.
After conversion, newly reported source sectors do not change contest grouping.

`structs.influence_ranked_standings` exposes live leaders and final `is_winner`
flags. At the inclusive ending block the highest positive score wins; exact ties
are shared, and an empty or all-zero contest has no winner. A single-sector
contest's overall-points tiebreaker is identical to its sector score.

Verification identifies the exact seeded range and published build. Revert removes
only this test contest's empty projections and configuration, preserving source
history and other contests. It refuses after raid/score data exists. The mode
conversion can only be reverted before completion while all source sectors are
still 0; scored data is retained and rebuilt. A second
normal Sqitch deployment is a no-op; direct duplicate registration is rejected.

Test locally with `python3 tests/test_influence_test_contest.py --image structs/structs-pg:latest`.
The conversion, winners and scoring-mode behavior are covered by
`python3 tests/test_influence_single_sector.py --image structs/structs-pg:latest`.
