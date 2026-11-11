#!/usr/bin/env python3
"""Test single-sector scoring and migrations with real PostgreSQL, Timescale and Sqitch."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
CHANGE = 'influence-test-contest-20261111'
CHAIN = 'structstestnet-111'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', required=True, help='Already installed structs-pg image')
    args = parser.parse_args()
    name = 'influence-single-test-' + uuid.uuid4().hex[:10]
    image = subprocess.check_output(['docker', 'image', 'inspect', args.image, '--format', '{{.Id}}'], text=True).strip()

    def run(*cmd, source=None, fail=None):
        r = subprocess.run(cmd, input=source, capture_output=True, text=True, timeout=120)
        if fail:
            assert r.returncode and fail in r.stdout + r.stderr, (cmd, r.stdout, r.stderr)
        elif r.returncode:
            raise RuntimeError(r.stdout + r.stderr)
        return r.stdout

    def sql(source, fail=None):
        return run('docker', 'exec', '-i', '-u', 'postgres', name, 'psql', '-XqAt', '-h', '/tmp',
                   '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', source=source, fail=fail)

    def sqitch(plan, action='deploy', fail=None, extra=()):
        opts = ['--verify'] if action == 'deploy' else ['-y'] if action == 'revert' else []
        return run('docker', 'exec', '-e', 'PGHOST=/tmp', '-e', 'SQITCH_FULL_NAME=Influence Test',
                   '-e', 'SQITCH_EMAIL=test@example.invalid', '-w', '/opt/influence-test', name,
                   'sqitch', '--plan-file', plan, action, *opts, *extra, '--target', 'db:postgres://postgres@/postgres', fail=fail)

    def boundary(h):
        sql(f"""INSERT INTO structs.current_block VALUES('{CHAIN}',{h-1});
SELECT structs.influence_begin_block('{CHAIN}',{h},'hash-{h}','2026-11-11T20:50:00Z',false);
SELECT structs.influence_finish_block('{CHAIN}',{h},'hash-{h}');
UPDATE structs.current_block SET height={h} WHERE chain='{CHAIN}';
INSERT INTO sync_state.sync_cursor VALUES('{CHAIN}',{h},'hash-{h}');""")

    try:
        run('docker', 'run', '--pull=never', '-d', '--name', name, '--network', 'none', '--user', 'postgres',
            '--tmpfs', '/tmp:rw,size=2147483648', '--entrypoint', '/bin/sh', image, '-ec',
            '/usr/lib/postgresql/18/bin/initdb -D /tmp/test-pg --auth=trust >/tmp/init.log; '
            'exec /usr/lib/postgresql/18/bin/postgres -D /tmp/test-pg -k /tmp '
            '-c listen_addresses= -c shared_preload_libraries=timescaledb -c shared_buffers=128MB')
        for _ in range(120):
            if subprocess.run(['docker', 'exec', name, 'pg_isready', '-h', '/tmp', '-U', 'postgres'], capture_output=True).returncode == 0:
                break
            time.sleep(.25)
        else:
            raise RuntimeError('database did not start')
        sql('''CREATE EXTENSION timescaledb; CREATE SCHEMA structs; CREATE SCHEMA sync_state;
CREATE ROLE structs_indexer; CREATE ROLE structs_webapp;
GRANT USAGE ON SCHEMA structs TO structs_indexer,structs_webapp;
CREATE TABLE structs.player(id text PRIMARY KEY,guild_id text);
CREATE TABLE structs.current_block(chain text PRIMARY KEY,height bigint);
CREATE TABLE sync_state.sync_cursor(chain_id text PRIMARY KEY,last_height bigint,last_block_hash text);
GRANT SELECT ON structs.player,structs.current_block TO structs_indexer;''')
        with tempfile.TemporaryDirectory(prefix='influence-sqitch-') as temp:
            path = Path(temp)
            for op in ['deploy', 'verify', 'revert']:
                (path/op).mkdir()
                for change in ['influence-schema-20261111', 'influence-projector-20261111', 'influence-single-sector-20261111', CHANGE, 'influence-test-contest-single-sector-20261111']:
                    shutil.copyfile(ROOT/op/(change+'.sql'), path/op/(change+'.sql'))
            shutil.copyfile(ROOT/'sqitch.test-contests.plan', path/'sqitch.test-contests.plan')
            (path/'sqitch.conf').write_text('[core]\nengine = pg\n')
            # A focused main-project plan uses the real migration scripts on
            # minimal entity tables. Cross-project dependencies are real Sqitch
            # registry checks, not a hand-written registry or a mocked CLI.
            (path/'sqitch.fixture.plan').write_text('''%syntax-version=1.0.0
%project=structs-pg

influence-schema-20261111 2026-11-11T20:00:00Z Influence Test <test@example.invalid>
influence-projector-20261111 [influence-schema-20261111] 2026-11-11T20:01:00Z Influence Test <test@example.invalid>
''')
            shutil.copyfile(path/'sqitch.fixture.plan', path/'sqitch.old.plan')
            with (path/'sqitch.fixture.plan').open('a') as f:
                f.write('influence-single-sector-20261111 [influence-projector-20261111] 2026-11-11T21:30:00Z Influence Test <test@example.invalid>\n')
            run('docker', 'exec', '-u', 'root', name, 'mkdir', '-p', '/opt/influence-test')
            run('docker', 'cp', str(path)+'/.', name+':/opt/influence-test/')
        sqitch('sqitch.fixture.plan')
        # Core migration reverts/reapplies cleanly before any single-mode contest.
        sqitch('sqitch.fixture.plan', 'revert', extra=('--to', 'influence-projector-20261111'))
        sqitch('sqitch.fixture.plan')
        # Probe older automation against an operator-applied newer schema.
        try:
            result = sqitch('sqitch.old.plan')
            print('Older main plan:', result.strip())
        except RuntimeError as e:
            print('Older main plan refuses newer schema:', str(e).strip())

        sql("INSERT INTO structs.player VALUES('a','G1'),('aa','G1'),('b','G3'),('c','G2');")

        def start(ch):
            sql(f"INSERT INTO structs.current_block VALUES('{ch}',0); SELECT structs.influence_begin_block('{ch}',1,'h1','2026-11-11T21:00:00Z',false); SELECT structs.influence_finish_block('{ch}',1,'h1');")

        def contest(ch, end=5, mode='single_sector'):
            suffix = ",1,'single_sector'" if mode == 'single_sector' else ''
            return sql(f"SELECT structs.influence_create_contest('{ch}',1,{end}{suffix});").strip()

        def block(ch, h, events=()):
            commands = [f"BEGIN; SET LOCAL ROLE structs_indexer; SELECT structs.influence_begin_block('{ch}',{h},'h{h}','2026-11-11T21:00:00Z',false);"]
            for i, event in enumerate(events):
                pos = json.dumps(dict(chain=ch,height=h,hash=f'h{h}',time='2026-11-11T21:00:00Z',phase=2,tx_index=0,event_index=i,msg_index=0))
                if event[0] == 'member':
                    guild = 'NULL' if event[2] is None else "'"+event[2]+"'"
                    commands.append(f"SELECT structs.influence_record_member('{pos}','{event[1]}',{guild});")
                else:
                    _, attacker, guild, planet, sector = event
                    fact = json.dumps(dict(attacker=attacker,defender='b',attacker_guild=guild,defender_guild='G3',planet=planet,sector=sector))
                    commands.append(f"SELECT structs.influence_record_raid('{pos}','{fact}');")
            commands.append(f"SELECT structs.influence_finish_block('{ch}',{h},'h{h}'); COMMIT;")
            sql('\n'.join(commands))

        def scores(cid):
            return sql(f"SELECT guild||':'||sector||':'||points||':'||state||':'||sector_rank||':'||tied_for_lead||':'||is_winner FROM structs.influence_ranked_standings WHERE contest_id={cid} ORDER BY guild,sector;").strip()

        start('single-fixture')
        cid = contest('single-fixture')
        sql("SELECT structs.influence_create_contest('single-fixture',1,5,1,'bad');", fail='unsupported influence scoring mode')
        sql(f"UPDATE structs.influence_contest SET scoring_mode='planet_sectors' WHERE contest_id={cid};", fail='immutable')
        sql("SET ROLE structs_webapp; SELECT structs.influence_create_contest('single-fixture',1,5,1,'single_sector');", fail='permission denied')
        sql("SET ROLE structs_indexer; SELECT structs.influence_create_contest('single-fixture',1,5,1,'single_sector');", fail='permission denied')
        sql((ROOT/'revert/influence-single-sector-20261111.sql').read_text(), fail='single-sector')
        block('single-fixture',2,[('raid','a','G1','p',0),('raid','aa','G1','p',127)])
        assert scores(cid) == 'G1:0:300:live:1:false:false', scores(cid)
        block('single-fixture',3,[('member','aa','G2'),('raid','aa','G2','q',999)])
        assert scores(cid) == 'G1:0:100:live:2:false:false\nG2:0:600:live:1:false:false', scores(cid)
        block('single-fixture',4,[('member','a','G2')])
        block('single-fixture',5)
        final = scores(cid)
        assert final == 'G1:0:0:final:2:false:false\nG2:0:600:final:1:false:true', final
        block('single-fixture',6,[('member','aa','G1'),('member','a','G1')])
        assert scores(cid) == final  # Inclusive end freezes membership.
        sql(f'SELECT structs.influence_rebuild({cid});')
        assert scores(cid) == final  # Replay produces the same final winner.
        assert sql("SELECT string_agg(sector::text,',' ORDER BY raid_id) FROM structs.influence_raid WHERE chain_id='single-fixture';").strip() == '0,127,999'
        assert sql(f"SELECT sum(mismatches) FROM structs.influence_published_build p CROSS JOIN LATERAL structs.influence_reconcile(p.build_id) WHERE p.contest_id={cid};").strip() == '0'

        start('ties-fixture')
        tied = contest('ties-fixture',3)
        block('ties-fixture',2,[('raid','a','G1','p',127),('raid','c','G2','q',44)])
        block('ties-fixture',3)
        assert scores(tied) == 'G1:0:300:final:1:true:true\nG2:0:300:final:1:true:true', scores(tied)
        start('zero-fixture')
        zero = contest('zero-fixture',3)
        block('zero-fixture',2,[('raid','a','G1','p',0),('member','a',None)])
        block('zero-fixture',3)
        assert scores(zero) == 'G1:0:0:final:1:false:false', scores(zero)
        start('geo-fixture')
        geo = contest('geo-fixture',3,'planet_sectors')
        block('geo-fixture',2,[('raid','a','G1','p',0)])
        block('geo-fixture',3)
        assert scores(geo) == 'G1:0:300:live:1:false:false', scores(geo)
        start('geo-tiebreak')
        geo_tie = contest('geo-tiebreak',3,'planet_sectors')
        block('geo-tiebreak',2,[('raid','a','G1','p',127),('raid','c','G2','q',127),('raid','a','G1','r',999)])
        block('geo-tiebreak',3)
        assert scores(geo_tie) == 'G1:127:300:final:1:false:true\nG1:999:300:final:1:false:true\nG2:127:300:final:2:false:false', scores(geo_tie)
        start('cleared-fixture')
        cleared = contest('cleared-fixture',3)
        block('cleared-fixture',2,[('raid','a','G1','p',0)])
        block('cleared-fixture',3,[('raid','b','G3','p',44)])
        assert scores(cleared) == 'G1:0:100:final:1:false:true', scores(cleared)
        start('empty-fixture')
        empty = contest('empty-fixture',2)
        block('empty-fixture',2)
        assert scores(empty) == ''
        assert sql(f"SELECT state FROM structs.influence_projection_build b JOIN structs.influence_published_build p USING(build_id) WHERE p.contest_id={empty};").strip() == 'final'

        # The dated conversion preserves source facts, identity, and existing score.
        boundary(3545600)
        block(CHAIN,3545601,[('raid','a','G1','seed-p',0)])
        sql(f"UPDATE structs.current_block SET height=3545601 WHERE chain='{CHAIN}'; UPDATE sync_state.sync_cursor SET last_height=3545601,last_block_hash='h3545601' WHERE chain_id='{CHAIN}';")
        optional = 'sqitch.test-contests.plan'
        sqitch(optional, extra=('--to', CHANGE))
        seeded = sql('SELECT contest_id FROM structs.influence_contest WHERE end_height=3626388;').strip()
        before = scores(seeded)
        sqitch(optional)
        assert scores(seeded) == before
        assert sql(f"SELECT scoring_mode FROM structs.influence_contest WHERE contest_id={seeded};").strip() == 'single_sector'
        sqitch(optional, 'verify')
        sqitch(optional, 'revert', extra=('--to', CHANGE))
        assert scores(seeded) == before
        sqitch(optional)
        block(CHAIN,3545602,[('raid','a','G1','seed-p',127)])
        assert scores(seeded) == before
        sqitch(optional,'revert',fail='known source sectors',extra=('--to',CHANGE))
        sqitch(optional,'verify')
        sql("SET ROLE structs_webapp; SELECT * FROM structs.influence_ranked_standings;")
        print('PASS: core migration lifecycle; mode/ACL guards; unknown and changing source sectors; guild overlap/transfers; finalization; frozen membership; exact rebuild; ties/zero/empty; geographic defaults; scored test conversion and safe rollback')
    finally:
        subprocess.run(['docker', 'rm', '-f', name], check=False, capture_output=True)


if __name__ == '__main__':
    main()
