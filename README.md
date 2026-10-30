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
