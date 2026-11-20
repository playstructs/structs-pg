#!/usr/bin/env python3
"""Test the official contest reset, history preservation and stream cutover in isolation."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
CHANGE = 'influence-official-contest-20261120'
REHEARSAL = 'influence-contest-20261117'
CHAIN = 'structstestnet-111'
START, END = 3743186, 3957791
OLD_START = 3633541
BASE = ['influence-schema-20261111', 'influence-projector-20261111',
        'influence-single-sector-20261111', 'influence-grass-20261111',
        'influence-player-history-read-20261111', REHEARSAL]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', required=True)
    parser.add_argument('--timescale-schema', choices=['structs', 'public'], default='structs',
                        help='Default matches the production extension installation')
    parser.add_argument('--stream-fixture', help='Optional JSON export for testing an existing client store')
    args = parser.parse_args()
    name = 'influence-official-reset-' + uuid.uuid4().hex[:10]
    database = 'postgres'

    def run(*cmd, source=None, fail=None):
        r = subprocess.run(cmd, input=source, capture_output=True, text=True, timeout=180)
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
        sql(f'CREATE SCHEMA structs; CREATE EXTENSION timescaledb WITH SCHEMA {args.timescale_schema};')
        sql(f'ALTER DATABASE {case} SET search_path=structs,public;')
        assert sql("SELECT n.nspname FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace WHERE e.extname='timescaledb';") == args.timescale_schema
        if args.timescale_schema == 'structs':
            assert sql("SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname='drop_chunks' AND n.nspname='public';") == '0'
        sql('''CREATE SCHEMA sync_state;
GRANT USAGE ON SCHEMA structs TO structs_indexer,structs_webapp;
CREATE TABLE structs.player(id text PRIMARY KEY,guild_id text);
CREATE TABLE structs.current_block(chain text PRIMARY KEY,height bigint);
CREATE TABLE sync_state.sync_cursor(chain_id text PRIMARY KEY,last_height bigint,last_block_hash text);
GRANT SELECT ON structs.player,structs.current_block TO structs_indexer;
INSERT INTO structs.player VALUES('a','G1'),('b','G2'),('c','G3');''')
        sqitch(to=BASE[-2])

    def block(h, *, bootstrap=False, raid=False, guild=None, commit=True, sector=44, planet='p'):
        statements = ['BEGIN;']
        if bootstrap:
            statements += [f"INSERT INTO structs.current_block VALUES('{CHAIN}',{h-1});"]
        statements += ['SET LOCAL ROLE structs_indexer;',
                       f"SELECT structs.influence_begin_block('{CHAIN}',{h},'h{h}','2026-11-24T16:00:00Z',false);"]
        pos = dict(chain=CHAIN, height=h, hash=f'h{h}', time='2026-11-24T16:00:00Z',
                   phase=2, tx_index=0, event_index=0, msg_index=0)
        if raid:
            fact = dict(attacker='a', defender='b', attacker_guild='G1', defender_guild='G2',
                        planet=planet, sector=sector)
            statements += [f"SELECT structs.influence_record_raid('{json.dumps(pos)}','{json.dumps(fact)}');"]
        if guild:
            statements += [f"SELECT structs.influence_record_member('{json.dumps(pos)}','a','{guild}');"]
        statements += [f"SELECT structs.influence_finish_block('{CHAIN}',{h},'h{h}');",
                       f"SELECT structs.influence_grass_flush('{CHAIN}',{h},'h{h}','2026-11-24T16:00:00Z');",
                       'RESET ROLE;', f"UPDATE structs.current_block SET height={h} WHERE chain='{CHAIN}';"]
        statements += ['COMMIT;' if commit else 'ROLLBACK;']
        sql('\n'.join(statements))

    def published():
        return sql('SELECT count(*) FROM structs.influence_published_build WHERE contest_id=1;')

    def scores():
        return sql('SELECT guild||\':\'||sector||\':\'||points||\':\'||state FROM structs.influence_ranked_standings WHERE contest_id=1 ORDER BY guild,sector;')

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
            (path / 'sqitch.conf').write_text('[core]\nengine = pg\n')
            lines = ['%syntax-version=1.0.0', '%project=structs-pg', '']
            for i, change in enumerate(BASE[:-1]):
                dependency = ' [' + BASE[i-1] + ']' if i else ''
                lines.append(f'{change}{dependency} 2026-11-11T20:0{i}:00Z Influence Test <test@example.invalid>')
            lines += [line for line in (ROOT / 'sqitch.plan').read_text().splitlines() if line.startswith((REHEARSAL + ' ', CHANGE + ' '))]
            (path / 'sqitch.plan').write_text('\n'.join(lines) + '\n')
            run('docker', 'exec', '-u', 'root', name, 'mkdir', '-p', '/opt/influence-test')
            run('docker', 'cp', str(path) + '/.', name + ':/opt/influence-test/')


        def fingerprint():
            return sql("""SELECT jsonb_build_object(
 'raids',(SELECT md5(coalesce(string_agg(to_jsonb(r)::text,'' ORDER BY raid_id),'')) FROM structs.influence_raid r),
 'memberships',(SELECT md5(coalesce(string_agg(to_jsonb(m)::text,'' ORDER BY chain_id,player,height,phase,tx_index,event_index,attribute_index),'')) FROM structs.influence_membership_history m),
 'cursor',(SELECT jsonb_agg(to_jsonb(c) ORDER BY chain_id) FROM structs.influence_source_cursor c),
 'players',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM structs.player p),
 'current_block',(SELECT jsonb_agg(to_jsonb(b) ORDER BY chain) FROM structs.current_block b),
 'raid_sequence',(SELECT jsonb_build_object('last_value',last_value,'is_called',is_called) FROM structs.influence_raid_raid_id_seq));""")

        def jump_empty(to):
            # Fixture-only shortcut over known-empty heights, not a deployment operation.
            sql(f"UPDATE structs.influence_source_cursor SET height={to},block_hash='h{to}' WHERE chain_id='{CHAIN}'; UPDATE structs.influence_projection_build b SET projected_height=least({to},c.end_height) FROM structs.influence_contest c WHERE b.contest_id=c.contest_id AND b.state='live'; UPDATE structs.current_block SET height={to} WHERE chain='{CHAIN}';")

        fresh('populated')
        block(OLD_START-1, bootstrap=True)
        assert sql(f"SELECT structs.influence_create_contest('{CHAIN}',{OLD_START-1},{OLD_START+2},1,'single_sector');") == '1'
        sqitch(to=REHEARSAL)
        block(OLD_START, raid=True)
        block(OLD_START+1, guild='G3')
        block(OLD_START+2, raid=True, sector=127, planet='q')
        old_builds = sql('SELECT array_agg(build_id)::text FROM structs.influence_projection_build;')
        assert int(sql('SELECT count(*) FROM structs.influence_score_change;')) > 0
        assert int(sql('SELECT count(*) FROM structs.influence_player_score_change;')) > 0
        sql(f"""CALL refresh_continuous_aggregate('structs.influence_score_change_1000',3633000::bigint,3634000::bigint);
INSERT INTO structs.influence_rollup_coverage SELECT build_id,3633000,1 FROM structs.influence_projection_build;
INSERT INTO structs.influence_checkpoint SELECT build_id,{OLD_START+2},guild,sector,unique_planets,held_planets FROM structs.influence_guild_sector;
INSERT INTO structs.influence_grass_dirty SELECT build_id,'player','a','G1' FROM structs.influence_projection_build ON CONFLICT DO NOTHING;
INSERT INTO structs.influence_rule_set(win_points,claim_points,policy) VALUES(999,999,'{{}}');
CREATE TABLE public.unrelated_history(id integer,body text); INSERT INTO public.unrelated_history VALUES(1,'keep');
INSERT INTO structs.influence_grass_delivery VALUES('caught-up',(SELECT max(frame_id) FROM structs.influence_grass_frame)),('behind',0);""")
        assert int(sql('SELECT count(*) FROM structs.influence_score_change_1000;')) > 0
        sql("""CREATE INDEX influence_custom_lookup ON structs.influence_score_change_1000(guild,bucket);
SELECT alter_job(add_continuous_aggregate_policy('structs.influence_score_change_1000',
 start_offset=>100000::bigint,end_offset=>1000::bigint,schedule_interval=>interval '1 hour',
 initial_start=>now()+interval '1 day'),scheduled=>false);""")
        def cache_config():
            return sql("""SELECT jsonb_build_object('oid','structs.influence_score_change_1000'::regclass::oid,
 'jobs',(SELECT jsonb_agg(to_jsonb(j) ORDER BY job_id) FROM timescaledb_information.jobs j),
 'indexes',(SELECT jsonb_agg(to_jsonb(i) ORDER BY indexname) FROM pg_indexes i WHERE schemaname='_timescaledb_internal' AND tablename LIKE '_materialized_hypertable_%'));
""")
        original_cache = cache_config()
        original = fingerprint()
        delivery = sql('SELECT jsonb_agg(to_jsonb(d) ORDER BY destination) FROM structs.influence_grass_delivery d;')
        max_frame = int(sql('SELECT max(frame_id) FROM structs.influence_grass_frame;'))
        max_build = int(sql('SELECT max(build_id) FROM structs.influence_projection_build;'))
        old_frames = json.loads(sql("SELECT jsonb_agg(payload ORDER BY frame_id) FROM structs.influence_grass_frame WHERE subject IN ('structs.influence.structstestnet-111.1.scores','structs.influence.structstestnet-111.1.guild.G1','structs.influence.structstestnet-111.2.scores');"))

        # Force a failure after data removal; all data, CAGG and sequence changes must roll back.
        original_frame_count = sql('SELECT count(*) FROM structs.influence_grass_frame;')
        sql("CREATE FUNCTION structs.influence_official_contest_initialize() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RETURN NEW; END $$;")
        sqitch(fail='already exists')
        assert fingerprint() == original
        assert sql('SELECT count(*) FROM structs.influence_contest;') == '2'
        assert sql('SELECT count(*) FROM structs.influence_grass_frame;') == original_frame_count
        assert int(sql('SELECT count(*) FROM structs.influence_score_change_1000;')) > 0
        sql('DROP FUNCTION structs.influence_official_contest_initialize();')
        sqitch()
        assert fingerprint() == original  # Includes full source rows, cursor/hash and sequence.
        assert cache_config() == original_cache
        assert sql('TABLE public.unrelated_history;') == '1|keep'
        assert sql('SELECT jsonb_agg(to_jsonb(d) ORDER BY destination) FROM structs.influence_grass_delivery d;') == delivery
        assert sql("SELECT contest_id||':'||chain_id||':'||start_height||':'||end_height||':'||scoring_mode FROM structs.influence_contest;") == f'1:{CHAIN}:{START}:{END}:planet_sectors'
        assert sql('SELECT count(*) FROM structs.influence_rule_set;') == '1'
        assert sql('SELECT last_value||\':\'||is_called FROM structs.influence_contest_contest_id_seq;') == '1:true'
        assert sql('SELECT last_value||\':\'||is_called FROM structs.influence_rule_set_rule_id_seq;') == '1:true'
        assert sql(f"SELECT count(*) FROM structs.influence_projection_build WHERE build_id=ANY('{old_builds}'::bigint[]);") == '0'
        new_build = int(sql('SELECT build_id FROM structs.influence_published_build WHERE contest_id=1;'))
        assert new_build > max_build
        assert int(sql('SELECT min(frame_id) FROM structs.influence_grass_frame;')) > max_frame
        for table in ['influence_contest_planet','influence_player_planet_win','influence_guild_planet_win',
                      'influence_planet_claim','influence_player_sector','influence_guild_sector',
                      'influence_score_change','influence_player_score_change','influence_checkpoint',
                      'influence_rollup_coverage','influence_score_change_1000','influence_grass_dirty']:
            assert sql('SELECT count(*) FROM structs.' + table) == '0', table
        assert published() == '1'
        assert sql(f"SELECT guild FROM structs.influence_member WHERE build_id={new_build} AND player='a';") == 'G3'
        assert sql(f"SELECT structs.influence_grass_context({new_build})->>'status';") == 'scheduled'
        assert sql('SELECT count(*) FROM structs.influence_member;') == '3'
        sqitch('verify')  # Includes the superseded November 17 verification.
        for old_verify in ['influence-test-contest-20261111','influence-test-contest-single-sector-20261111']:
            sql((ROOT/'verify'/(old_verify+'.sql')).read_text())
        assert sql("SELECT count(*) FROM structs.influence_grass_frame WHERE contest_id=2 AND (payload->'context'->>'status'<>'removed' OR payload->>'mode'<>'replace');") == '0'
        assert sql("SELECT count(*) FROM structs.influence_grass_frame WHERE contest_id=2 AND payload->'context' ? 'start_height';") == '0'
        absent = json.loads(sql(f"SELECT payload FROM structs.influence_grass_frame WHERE subject='structs.influence.{CHAIN}.1.planet.p' ORDER BY frame_id DESC LIMIT 1;"))
        assert absent['data']['exists'] is False and absent['data']['latest_raid'] is None
        assert absent['build_id'] == str(new_build)
        # Model an already-running relay: its cached high-water cursor still reaches every new frame.
        assert sql(f'SELECT count(*)=(SELECT count(*) FROM structs.influence_grass_frame) FROM structs.influence_grass_frame WHERE frame_id>{max_frame};') == 't'
        new_frames = json.loads(sql("SELECT jsonb_agg(payload ORDER BY frame_id) FROM structs.influence_grass_frame WHERE subject IN ('structs.influence.structstestnet-111.1.scores','structs.influence.structstestnet-111.1.guild.G1','structs.influence.structstestnet-111.2.scores');"))
        if args.stream_fixture:
            Path(args.stream_fixture).write_text(json.dumps(dict(before=old_frames, after=new_frames)) + '\n')

        # Official-only events, all sectors, inclusive boundaries and portable contributions.
        jump_empty(START-2)
        block(START-1, raid=True, planet='outside')
        assert scores() == ''
        block(START, raid=True, sector=44, planet='s44')
        block(START+1, raid=True, sector=127, planet='s127')
        block(START+2, raid=True, sector=999, planet='s999')
        assert scores() == 'G3:44:300:live\nG3:127:300:live\nG3:999:300:live', scores()
        sql("CALL refresh_continuous_aggregate('structs.influence_score_change_1000',3743000::bigint,3744000::bigint);")
        assert sql('SELECT sum(unique_delta)||\':\'||sum(claim_delta) FROM structs.influence_score_change_1000;') == '3:3'
        assert cache_config() == original_cache
        before_redeploy = scores()
        sqitch()
        assert scores() == before_redeploy  # Repeat deployment must not reset official gameplay.
        # Direct script rerun must roll back rather than reset scored official data.
        sql((ROOT/'deploy'/(CHANGE+'.sql')).read_text(), fail='does not exist')
        assert scores() == before_redeploy
        jump_empty(END-1)
        block(END, guild='G1')
        final = scores()
        assert final == 'G1:44:300:final\nG1:127:300:final\nG1:999:300:final\nG3:44:0:final\nG3:127:0:final\nG3:999:0:final', final
        block(END+1, guild='G3', raid=True, planet='after')
        assert scores() == final
        assert sql('SELECT sum(mismatches) FROM structs.influence_published_build p CROSS JOIN LATERAL structs.influence_reconcile(p.build_id) WHERE p.contest_id=1;') == '0'
        sqitch('verify')
        sqitch('revert', fail='cannot restore deleted test data', to=REHEARSAL)
        assert sql("SELECT nextval('structs.influence_contest_contest_id_seq');") == '2'
        print('PASS populated reset, rollback, canonical history, cache removal, Grass generations and official gameplay', flush=True)

        fresh('before_writer')
        sqitch()
        assert published() == '0'
        assert sql('SELECT count(*) FROM structs.influence_contest;') == '1'
        for role in ['structs_webapp','structs_indexer']:
            sql(f'SET ROLE {role}; SELECT structs.influence_official_contest_initialize();', fail='permission denied')
        block(START, bootstrap=True, raid=True, commit=False)
        assert published() == '0'
        block(START, bootstrap=True, raid=True)
        assert published() == '1'
        assert scores() == 'G1:44:300:live'
        block(START+1)
        assert sql('SELECT count(*) FROM structs.influence_contest;') == '1'
        assert sql('SELECT count(*) FROM structs.influence_projection_build;') == '1'
        sqitch('verify')
        print('PASS fresh install, non-superuser deferred initialization and no test-contest resurrection', flush=True)

        fresh('late_deployment')
        block(START, bootstrap=True, raid=True, sector=999)
        original = fingerprint()
        sqitch()
        assert fingerprint() == original
        assert scores() == 'G1:999:300:live'
        sqitch('verify')

        fresh('after_end')
        block(START, bootstrap=True, raid=True)
        jump_empty(END)
        block(END+1, raid=True, sector=127, planet='too-late')
        original = fingerprint()
        sqitch()
        assert fingerprint() == original
        assert scores() == 'G1:44:300:final'
        sqitch('verify')

        fresh('missing_history')
        block(START+1, bootstrap=True)
        sqitch()
        block(START+2)
        assert published() == '0'
        assert sql('SELECT count(*) FROM structs.influence_contest;') == '1'
        sqitch('verify')

        fresh('other_chain')
        sql("INSERT INTO structs.influence_source_cursor VALUES('other-chain',1,0,'');")
        original = fingerprint()
        sqitch()
        assert fingerprint() == original
        assert published() == '0'
        sqitch('verify')
        print(f'PASS late/finished deployment replay, inadequate coverage and unrelated chain preservation (Timescale schema: {args.timescale_schema})', flush=True)
    finally:
        subprocess.run(['docker', 'rm', '-f', name], check=False, capture_output=True)


if __name__ == '__main__':
    main()
