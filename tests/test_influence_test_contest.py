#!/usr/bin/env python3
"""Test the optional contest migration with real Sqitch in a disposable database."""
import argparse
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
    name = 'influence-contest-test-' + uuid.uuid4().hex[:10]
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

    def sqitch(plan, action='deploy', fail=None):
        opts = ['--verify'] if action == 'deploy' else ['-y'] if action == 'revert' else []
        return run('docker', 'exec', '-e', 'PGHOST=/tmp', '-e', 'SQITCH_FULL_NAME=Influence Test',
                   '-e', 'SQITCH_EMAIL=test@example.invalid', '-w', '/opt/influence-test', name,
                   'sqitch', '--plan-file', plan, action, *opts, '--target', 'db:postgres://postgres@/postgres', fail=fail)

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
CREATE TABLE sync_state.sync_cursor(chain_id text PRIMARY KEY,last_height bigint,last_block_hash text);''')
        with tempfile.TemporaryDirectory(prefix='influence-sqitch-') as temp:
            path = Path(temp)
            for op in ['deploy', 'verify', 'revert']:
                (path/op).mkdir()
                for change in ['influence-schema-20261111', 'influence-projector-20261111', CHANGE]:
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
            run('docker', 'exec', '-u', 'root', name, 'mkdir', '-p', '/opt/influence-test')
            run('docker', 'cp', str(path)+'/.', name+':/opt/influence-test/')
        optional = 'sqitch.test-contests.plan'
        sqitch(optional, fail='influence-projector-20261111')
        sqitch('sqitch.fixture.plan')
        sqitch(optional, fail='start the influence writer')
        # The wrong chain cannot activate this seed.
        sql("INSERT INTO structs.influence_source_cursor VALUES('different-chain',1,1,'other');")
        sqitch(optional, fail='start the influence writer')
        sql("DELETE FROM structs.influence_source_cursor WHERE chain_id='different-chain';")
        boundary(3626388)
        sqitch(optional, fail='window has ended')
        sql('DELETE FROM structs.influence_source_cursor; DELETE FROM structs.current_block; DELETE FROM sync_state.sync_cursor;')
        boundary(3545600)
        sql("UPDATE sync_state.sync_cursor SET last_block_hash='wrong';")
        sqitch(optional, fail='must match the canonical sync cursor')
        sql("UPDATE sync_state.sync_cursor SET last_block_hash='hash-3545600';")
        other = sql(f"SELECT structs.influence_create_contest('{CHAIN}',3545600,3626000);").strip()
        sqitch(optional)
        assert sql(f"SELECT start_height||':'||end_height FROM structs.influence_contest WHERE end_height=3626388;").strip() == '3545600:3626388'
        sqitch(optional)  # Already applied: no duplicate contest.
        sql((ROOT/'deploy'/(CHANGE+'.sql')).read_text(), fail='refusing duplicate registration')
        sqitch(optional, 'verify')
        sqitch(optional, 'revert')
        assert sql(f'SELECT count(*) FROM structs.influence_contest WHERE contest_id={other};').strip() == '1'
        assert sql('SELECT count(*) FROM structs.influence_contest WHERE end_height=3626388;').strip() == '0'
        # Re-deploy and score a real projector event. Revert must preserve it.
        sqitch(optional)
        sql(f"""BEGIN;
SELECT structs.influence_begin_block('{CHAIN}',3545601,'hash-3545601','2026-11-11T20:50:06Z',false);
DO $$ DECLARE p jsonb:=jsonb_build_object('chain','{CHAIN}','height',3545601,'hash','hash-3545601',
 'time','2026-11-11T20:50:06Z','phase',2,'tx_index',0,'event_index',0,'msg_index',0);
BEGIN
 PERFORM structs.influence_record_member(p,'1-a','0-a');
 p:=p||'{{"event_index":1}}'::jsonb;
 PERFORM structs.influence_record_member(p,'1-b','0-b');
 p:=p||'{{"event_index":2}}'::jsonb;
 PERFORM structs.influence_record_raid(p,'{{"attacker":"1-a","defender":"1-b","attacker_guild":"0-a","defender_guild":"0-b","planet":"2-a","sector":127}}');
END $$;
SELECT structs.influence_finish_block('{CHAIN}',3545601,'hash-3545601');
UPDATE structs.current_block SET height=3545601;
UPDATE sync_state.sync_cursor SET last_height=3545601,last_block_hash='hash-3545601';
COMMIT;""")
        sqitch(optional, 'revert', fail='contains raid/score data')
        sqitch(optional, 'verify')
        assert sql('SELECT points FROM structs.influence_standings s JOIN structs.influence_contest c USING(contest_id) WHERE c.end_height=3626388;').strip() == '300'
        print('PASS: Sqitch cross-project dependency, coverage/chain/hash/end guards, adjusted start, deploy/verify/revert/redeploy, idempotence, other-contest preservation and scored-revert protection')
    finally:
        subprocess.run(['docker', 'rm', '-f', name], check=False, capture_output=True)


if __name__ == '__main__':
    main()
