# structs-pg
**structs-pg** provides the a postgres database layer for Structs guild infrastructure

Most players within the Structs ecosystem will not need to operate the code in this repository. 

## Structs
In the distant future the species of the galaxy are embroiled in a race for Alpha Matter, the rare and dangerous substance that fuels galactic civilization. Players take command of Structs, a race of sentient machines, and must forge alliances, conquer enemies and expand their influence to control Alpha Matter and the fate of the galaxy.

[Structs](https://playstructs.com) is a decentralized game in the Cosmos ecosystem, operated and governed by our community of players--ensuring Structs remains online as long as there are players to play it.

## Get started
**structs-pg** uses [Sqitch](https://sqitch.org/) to orchestrate the deployment of the Structs postgres database, including verification and revert capabilities. 

### Install Sqitch
Sqitch [Install Options](https://sqitch.org/download/)


### Database Deployment
If you haven't already, create the structs database `createdb structs`

```
sqitch deploy db:pg:structs
```


## Learn more

- [Structs](https://playstructs.com)
- [Project Wiki](https://watt.wiki)
- [@PlayStructs Twitter](https://twitter.com/playstructs)


## License

Copyright 2021 [Slow Ninja Inc](https://slow.ninja).

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
### Exact work values in v0.22

`table-work-20261030-uint64` preserves unsigned chain values through struct/planet
attributes, the three work difficulties in `struct_type`, and the two work
projection fields. These use unscaled `NUMERIC` with exact uint64 checks; view
status flags use integer `div()` rather than rounding numeric division. Existing
view owners, grants, options and comments, and work dirty-trigger states survive
the type change. Unknown dependent views block deployment transactionally.

Apply this tail with the matching sync-state writer; the legacy SQL cache writer
still has signed integer parsing and is not a full-range fallback. The normal
compatible automatic migration target is unchanged. This DDL takes table locks
and may rewrite attribute/projection data, so include it in the coordinated
pause and measure it on the representative restore before activation. Reversal
refuses values outside the previous integer range instead of truncating them.

On the labelled disposable database, run `tests/v022-work-uint64.sql` with psql
and `python3 tests/work_uint64_lifecycle.py`. The latter tests transactional
revert/deploy metadata preservation and refused reversals without retaining
fixtures. Writer and API exact-value integration tests live in their respective
repositories.

## Onboarding telemetry exclusions (2026-11-10)

Deploy `table-onboarding-20261110-telemetry-exclusion` in structs-pg before
releasing the matching webapp API changes. This creates
`structs.onboarding_telemetry_exclusion` with `player_id` (primary key), optional
`reason`, and `created_at`. The webapp has SELECT only; maintain the list with
SQL using an administrative database role. There is no management API or player
foreign key, so the list may be loaded before the indexer knows a player.

```sql
INSERT INTO structs.onboarding_telemetry_exclusion (player_id, reason)
VALUES ('1-123', 'Internal testing'), ('1-456', 'Demo account')
ON CONFLICT (player_id) DO UPDATE SET reason = EXCLUDED.reason;

-- Restore a player to reports:
DELETE FROM structs.onboarding_telemetry_exclusion WHERE player_id = '1-123';
```

Onboarding aggregates are SQL queries in Symfony `OnboardingManager`, executed
on each request. They do not use SQL views, scheduled rollups, or materialized
aggregates. Changes to the list therefore affect historical and future reports
immediately without rebuilding data. Raw event collection is unchanged.

All six report endpoints under `/api/onboarding` accept `include_excluded=0`
(the default) or `include_excluded=1` (include everyone):

- `/funnel/{content_version}/{phase}`
- `/tutorial/outcome/{content_version}`
- `/tutorial/players/{content_version}`
- `/tutorial/players/{content_version}/steps`
- `/tutorial/runs/{content_version}/comparison`
- `/tutorial/runs/{content_version}`

Other values return HTTP 400. Existing filters combine with this option.
Exclusions remove whole sessions linked by any progress row to a listed player,
including that session's earlier anonymous signup events and later replay runs.
Run numbering is computed before report filtering. Sessions with no player link
remain counted; browser identity is not used to infer exclusions across sessions.
The catalog and `/player/{player_id}` raw event history remain available.
Reverting the migration drops the exclusion list; export it first if needed and
roll back the API release before reverting the table.

### Username regex exclusions

`table-onboarding-20261110-username-exclusion` adds
`structs.onboarding_telemetry_username_exclusion` and seeds the generated test
account rule `^T[0-9]{6}-?[0-9]{4}([0-9]{2})?$`. Deploy it before the updated API.
For example, it matches `T261110-1234`, `T2611101234`, `T261110-123456`, and
`T261110123456`. Matching is case-sensitive and the anchors require the entire
username to match. These are PostgreSQL regular expressions, not PCRE.

```sql
INSERT INTO structs.onboarding_telemetry_username_exclusion (username_regex, reason)
VALUES ('^T[0-9]{6}-?[0-9]{4}([0-9]{2})?$', 'Generated test accounts')
ON CONFLICT (username_regex) DO UPDATE SET reason = EXCLUDED.reason;
```

Regex rules and explicit player IDs combine: either excludes the player's
linked sessions, and `include_excluded=1` bypasses both. Rules match the current
`structs.player.username`, so username changes or indexer updates can change
historical results. Use an explicit ID when an exclusion should survive renames.
Null usernames do not match. Invalid or empty regexes are rejected on insertion.
Manage rules by SQL; the webapp receives SELECT only. Reverting this migration
removes all regex rules, so export them first if needed.
