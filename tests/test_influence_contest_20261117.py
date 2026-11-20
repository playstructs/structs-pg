#!/usr/bin/env python3
"""Exercise the historical rehearsal fixture; current upgrade paths are tested in test_influence_official_contest.py."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
CHANGE = 'influence-contest-20261117'
CHAIN = 'structstestnet-111'
START, END = 3633541, 3649817
BASE = ['influence-schema-20261111', 'influence-projector-20261111',
        'influence-single-sector-20261111', 'influence-grass-20261111',
        'influence-player-history-read-20261111']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', required=True)
    args = parser.parse_args()
    name = 'influence-contest-20261117-' + uuid.uuid4().hex[:10]
    database = 'postgres'

    def run(*cmd, source=None, fail=None):
        r = subprocess.run(cmd, input=source, capture_output=True, text=True, timeout=120)
        if fail:
            assert r.returncode and fail in r.stdout + r.stderr, (cmd, r.stdout, r.stderr)
        elif r.returncode:
            raise RuntimeError(r.stdout + r.stderr)
        return r.stdout.strip()

    def sql(source, fail=None):
        return run('docker', 'exec', '-i', '-u', 'postgres', name, 'psql', '-XqAt', '-h', '/tmp',
                   '-U', 'postgres', '-d', database, '-v', 'ON_ERROR_STOP=1', source=source, fail=fail)

    def sqitch(action='deploy', fail=None, to=None):
        opts = ['--verify'] if action == 'deploy' else ['-y'] if action == 'revert' else []
        if to:
            opts += ['--to', to]
        return run('docker', 'exec', '-e', 'PGHOST=/tmp', '-e', 'SQITCH_FULL_NAME=Influence Test',
                   '-e', 'SQITCH_EMAIL=test@example.invalid', '-w', '/opt/influence-test', name,
                   'sqitch', action, *opts, '--target', 'db:postgres://postgres@/' + database, fail=fail)

    def fresh(case):
        nonlocal database
        database = 'postgres'
        sql('CREATE DATABASE ' + case)
        database = case
        sql('''CREATE EXTENSION timescaledb; CREATE SCHEMA structs; CREATE SCHEMA sync_state;
GRANT USAGE ON SCHEMA structs TO structs_indexer,structs_webapp;
CREATE TABLE structs.player(id text PRIMARY KEY,guild_id text);
CREATE TABLE structs.current_block(chain text PRIMARY KEY,height bigint);
CREATE TABLE sync_state.sync_cursor(chain_id text PRIMARY KEY,last_height bigint,last_block_hash text);
GRANT SELECT ON structs.player,structs.current_block TO structs_indexer;
INSERT INTO structs.player VALUES('a','G1'),('b','G2'),('c','G3');''')
        sqitch(to=BASE[-1])

    def block(h, *, bootstrap=False, raid=False, guild=None, commit=True):
        statements = ['BEGIN;']
        if bootstrap:
            statements += [f"INSERT INTO structs.current_block VALUES('{CHAIN}',{h-1});"]
        statements += ['SET LOCAL ROLE structs_indexer;',
                       f"SELECT structs.influence_begin_block('{CHAIN}',{h},'h{h}','2026-11-17T15:27:32Z',false);"]
        pos = dict(chain=CHAIN, height=h, hash=f'h{h}', time='2026-11-17T15:27:32Z',
                   phase=2, tx_index=0, event_index=0, msg_index=0)
        if raid:
            fact = dict(attacker='a', defender='b', attacker_guild='G1', defender_guild='G2',
                        planet='p', sector=44)
            statements += [f"SELECT structs.influence_record_raid('{json.dumps(pos)}','{json.dumps(fact)}');"]
        if guild:
            statements += [f"SELECT structs.influence_record_member('{json.dumps(pos)}','a','{guild}');"]
        statements += [f"SELECT structs.influence_finish_block('{CHAIN}',{h},'h{h}');",
                       f"SELECT structs.influence_grass_flush('{CHAIN}',{h},'h{h}','2026-11-17T15:27:32Z');",
                       'RESET ROLE;', f"UPDATE structs.current_block SET height={h} WHERE chain='{CHAIN}';"]
        statements += ['COMMIT;' if commit else 'ROLLBACK;']
        sql('\n'.join(statements))

    def published():
        return sql('SELECT count(*) FROM structs.influence_published_build WHERE contest_id=2;')

    def scores():
        return sql('SELECT guild||\':\'||sector||\':\'||points||\':\'||state FROM structs.influence_ranked_standings WHERE contest_id=2 ORDER BY guild,sector;')

    try:
        run('docker', 'run', '--pull=never', '-d', '--name', name, '--network', 'none', '--user', 'postgres',
            '--tmpfs', '/tmp:rw,size=2147483648', '--entrypoint', '/bin/sh', args.image, '-ec',
            '/usr/lib/postgresql/18/bin/initdb -D /tmp/test-pg --auth=trust >/tmp/init.log; '
            'exec /usr/lib/postgresql/18/bin/postgres -D /tmp/test-pg -k /tmp '
            '-c listen_addresses= -c shared_preload_libraries=timescaledb -c shared_buffers=128MB')
        for _ in range(120):
            if subprocess.run(['docker', 'exec', name, 'pg_isready', '-h', '/tmp', '-U', 'postgres'], capture_output=True).returncode == 0:
                break
            time.sleep(.25)
        else:
            raise RuntimeError('database did not start')
        sql('CREATE ROLE structs_indexer; CREATE ROLE structs_webapp;')
        with tempfile.TemporaryDirectory(prefix='influence-contest-sqitch-') as temp:
            path = Path(temp)
            for op in ['deploy', 'verify', 'revert']:
                (path / op).mkdir()
                for change in [*BASE, CHANGE]:
                    shutil.copyfile(ROOT / op / (change + '.sql'), path / op / (change + '.sql'))
            shutil.copyfile(ROOT / 'tests/fixtures/influence-contest-20261117-original.sql',
                            path / 'deploy' / (CHANGE + '.sql'))
            (path / 'sqitch.conf').write_text('[core]\nengine = pg\n')
            lines = ['%syntax-version=1.0.0', '%project=structs-pg', '']
            for i, change in enumerate(BASE):
                dependency = ' [' + BASE[i-1] + ']' if i else ''
                lines.append(f'{change}{dependency} 2026-11-11T20:0{i}:00Z Influence Test <test@example.invalid>')
            lines += [line for line in (ROOT / 'sqitch.plan').read_text().splitlines() if line.startswith(CHANGE + ' ')]
            (path / 'sqitch.plan').write_text('\n'.join(lines) + '\n')
            run('docker', 'exec', '-u', 'root', name, 'mkdir', '-p', '/opt/influence-test')
            run('docker', 'cp', str(path) + '/.', name + ':/opt/influence-test/')

        fresh('ready')
        block(START-2, bootstrap=True)
        old = sql(f"SELECT structs.influence_create_contest('{CHAIN}',{START-2},{START-2},1,'single_sector');")
        assert old == '1'
        sqitch()
        assert published() == '1'
        assert sql("SELECT scoring_mode FROM structs.influence_contest WHERE contest_id=2;") == 'planet_sectors'
        assert sql('SELECT count(*) FROM structs.influence_member WHERE build_id=(SELECT build_id FROM structs.influence_published_build WHERE contest_id=2);') == '3'
        assert sql('SELECT count(*) FROM structs.influence_contest WHERE contest_id=1;') == '1'
        assert int(sql("SELECT nextval('structs.influence_contest_contest_id_seq');")) > 2
        before = sql('SELECT build_id FROM structs.influence_published_build WHERE contest_id=2;')
        sqitch()  # Registry idempotence: no rebuild or repeated grass replacement.
        assert before == sql('SELECT build_id FROM structs.influence_published_build WHERE contest_id=2;')
        block(START-1, raid=True)
        assert scores() == ''
        block(START, raid=True)
        assert scores() == 'G1:44:300:live', scores()
        # Skip only empty fixture heights; the inclusive end must still apply membership.
        sql(f"UPDATE structs.influence_source_cursor SET height={END-1},block_hash='h{END-1}' WHERE chain_id='{CHAIN}'; UPDATE structs.influence_projection_build SET projected_height={END-1} WHERE build_id={before};")
        block(END, guild='G3')
        final = scores()
        assert final == 'G1:44:0:final\nG3:44:300:final', final
        block(END+1, guild='G1')
        assert scores() == final
        assert sql('SELECT sum(mismatches) FROM structs.influence_published_build p CROSS JOIN LATERAL structs.influence_reconcile(p.build_id) WHERE p.contest_id=2;') == '0'
        sqitch('verify')
        sqitch('revert', fail='durable network-wide contest', to=BASE[-1])

        fresh('before_writer')
        sqitch()
        assert published() == '0'
        sql("SET ROLE structs_webapp; SELECT structs.influence_contest_20261117_initialize();", fail='permission denied')
        sql("SET ROLE structs_indexer; SELECT structs.influence_contest_20261117_initialize();", fail='permission denied')
        block(START, bootstrap=True, raid=True, commit=False)
        assert published() == '0'
        block(START, bootstrap=True, raid=True)
        assert published() == '1'
        assert scores() == 'G1:44:300:live', scores()
        assert sql("SELECT count(*) FROM structs.influence_grass_frame WHERE contest_id=2 AND payload->>'category'='influence_contest';") == '1'
        sqitch('verify')

        fresh('late_deployment')
        block(START-1, bootstrap=True)
        block(START, raid=True)
        sqitch()
        assert scores() == 'G1:44:300:live'
        sqitch('verify')

        fresh('missing_history')
        block(START+1, bootstrap=True)
        sqitch()
        block(START+2)
        assert published() == '0'
        sqitch('verify')

        fresh('other_chain')
        sql("INSERT INTO structs.influence_source_cursor VALUES('other-chain',1,0,'');")
        sqitch()
        assert published() == '0'
        sqitch('verify')

        fresh('conflict')
        sql(f"INSERT INTO structs.influence_contest VALUES(2,'{CHAIN}',1,2,1,'single_sector');")
        sqitch(fail='contest ID 2 is already used')
        assert sql('SELECT start_height FROM structs.influence_contest WHERE contest_id=2;') == '1'
        assert sql("SELECT count(*) FROM pg_trigger WHERE tgname='influence_contest_20261117_initialize';") == '0'
        print('PASS: existing/fresh guild identity, deferred non-superuser initialization, rollback atomicity, late replay, missing coverage, other chain, conflicts, grass, sectors, inclusive boundaries, transfers, final freeze and verification')
    finally:
        subprocess.run(['docker', 'rm', '-f', name], check=False, capture_output=True)


if __name__ == '__main__':
    main()
