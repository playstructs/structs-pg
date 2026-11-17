"""Integration test against a disposable container, never the application database.
Run: TIMESCALE_TEST_CONTAINER=structs-pg-timescale-migration-test python3 tests/test_timescale_portal_workaround.py
The container must start with the image's empty structs database.
"""
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
CHANGE = 'timescaledb-jobs-20261117-portal-workaround'
CONTAINER = os.environ['TIMESCALE_TEST_CONTAINER']
assert CONTAINER.startswith('structs-pg-timescale-') and CONTAINER.endswith('-test')


def sql(query, ok=True):
    result = subprocess.run(['docker', 'exec', '-i', '-u', 'postgres', CONTAINER,
        'psql', '-X', '-h', '/var/run/postgresql', '-U', 'postgres', '-d', 'structs',
        '-At', '-v', 'ON_ERROR_STOP=1'], input=query, text=True, capture_output=True)
    if ok and result.returncode:
        raise AssertionError(result.stderr)
    if not ok:
        assert result.returncode, 'Expected failure'
    return result.stdout.strip()


def migration(kind, ok=True):
    return sql((ROOT / kind / (CHANGE + '.sql')).read_text(), ok)


# Refuse a populated database before constructing a minimal actual Timescale fixture.
assert sql("SELECT to_regclass('structs.planet_activity') IS NULL") == 't'
sql('''CREATE SCHEMA structs AUTHORIZATION structs;
CREATE EXTENSION timescaledb WITH SCHEMA structs VERSION '2.31.0';
CREATE EXTENSION pg_cron;
SET ROLE structs;
SET search_path=structs,public;
CREATE TABLE planet_activity(time timestamptz NOT NULL, planet_id text);
SELECT create_hypertable('planet_activity','time');
CREATE TABLE planet_activity_player(time timestamptz NOT NULL, player_id text);
SELECT create_hypertable('planet_activity_player','time');
CREATE MATERIALIZED VIEW planet_activity_hourly WITH(timescaledb.continuous) AS
 SELECT time_bucket('1 hour',time) bucket,planet_id,count(*) FROM planet_activity GROUP BY 1,2 WITH NO DATA;
CREATE MATERIALIZED VIEW planet_activity_daily WITH(timescaledb.continuous) AS
 SELECT time_bucket('1 day',bucket) bucket,planet_id,sum(count) FROM planet_activity_hourly GROUP BY 1,2 WITH NO DATA;
CREATE MATERIALIZED VIEW planet_activity_player_daily WITH(timescaledb.continuous) AS
 SELECT time_bucket('1 day',time) bucket,player_id,count(*) FROM planet_activity_player GROUP BY 1,2 WITH NO DATA;
-- Consume an ID so discovery cannot accidentally depend on the incident IDs.
CREATE PROCEDURE structs.test_noop(integer,jsonb) LANGUAGE plpgsql AS $$ BEGIN NULL; END $$;
SELECT add_job('structs.test_noop','1 day');
SELECT add_continuous_aggregate_policy('planet_activity_hourly','3 days'::interval,'10 minutes'::interval,'10 minutes'::interval);
SELECT add_continuous_aggregate_policy('planet_activity_daily','7 days'::interval,'1 hour'::interval,'1 hour'::interval);
SELECT add_continuous_aggregate_policy('planet_activity_player_daily','7 days'::interval,'1 hour'::interval,'1 hour'::interval);
ALTER TABLE planet_activity SET(timescaledb.compress,timescaledb.compress_segmentby='planet_id');
SELECT add_compression_policy('planet_activity','30 days'::interval);
''')
# Keep background policies idle during test setup.
sql("SELECT structs.alter_job(job_id,next_start=>now()+interval '1 day') FROM timescaledb_information.jobs")
baseline = sql('SELECT job_id,scheduled FROM timescaledb_information.jobs ORDER BY job_id')
migration('deploy'); migration('verify')
assert sql('SELECT count(*) FROM structs.timescale_portal_workaround WHERE cron_job_id IS NOT NULL') == '5'
# Exercise the real pg_cron worker path, not just foreground SQL.
sql("SELECT cron.alter_job(cron_job_id,schedule=>'10 seconds') FROM structs.timescale_portal_workaround")
time.sleep(15)
assert sql("SELECT count(DISTINCT r.jobid) FROM cron.job_run_details r JOIN structs.timescale_portal_workaround s ON s.cron_job_id=r.jobid WHERE status='succeeded'") == '5'
assert sql("SELECT count(*) FROM cron.job_run_details r JOIN structs.timescale_portal_workaround s ON s.cron_job_id=r.jobid WHERE status='failed'") == '0'
sql('SELECT cron.alter_job(cron_job_id,schedule=>cron_schedule,active=>false) FROM structs.timescale_portal_workaround')
migration('revert')
assert sql('SELECT job_id,scheduled FROM timescaledb_information.jobs ORDER BY job_id') == baseline
assert sql("SELECT count(*) FROM cron.job WHERE jobname LIKE 'timescale-portal-workaround-%'") == '0'
print('PASS fresh deploy, dynamic IDs, five real scheduled executions, exact native-state rollback')
# Adoption must restore the incident workaround, not silently remove it on revert.
migration('deploy')
sql('DROP TABLE structs.timescale_portal_workaround;')
adopted = sql("SELECT jobid,schedule,command,username,active FROM cron.job ORDER BY jobid")
migration('deploy'); migration('verify')
assert sql('SELECT count(*) FROM structs.timescale_portal_workaround WHERE cron_preexisting') == '5'
sql('SELECT cron.alter_job(cron_job_id,active=>false) FROM structs.timescale_portal_workaround')
migration('revert')
assert sql("SELECT jobid,schedule,command,username,active FROM cron.job ORDER BY jobid") == adopted
print('PASS existing workaround adoption and rollback preservation')
# Inactive native policies without a workaround remain inactive.
sql("SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname LIKE 'timescale-portal-workaround-%'")
migration('deploy'); migration('verify')
assert sql('SELECT count(*) FROM structs.timescale_portal_workaround WHERE cron_job_id IS NULL') == '5'
migration('revert')
print('PASS intentionally disabled policies stay disabled')
# A conflict must roll back all partial changes.
sql("SELECT structs.alter_job(job_id,scheduled=>true,next_start=>now()+interval '1 day') FROM timescaledb_information.jobs")
sql("SELECT cron.schedule('timescale-portal-workaround-'||job_id,'* * * * *','SELECT 1') FROM timescaledb_information.jobs WHERE proc_name='policy_compression'")
before = sql('SELECT job_id,scheduled FROM timescaledb_information.jobs ORDER BY job_id')
migration('deploy',ok=False)
assert sql("SELECT to_regclass('structs.timescale_portal_workaround') IS NULL") == 't'
assert sql('SELECT job_id,scheduled FROM timescaledb_information.jobs ORDER BY job_id') == before
print('PASS conflicting cron configuration fails atomically')
sql("SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname LIKE 'timescale-portal-workaround-%'")
migration('deploy')
sql("SELECT cron.alter_job(min(cron_job_id),command=>'SELECT 1') FROM structs.timescale_portal_workaround")
migration('verify',ok=False)
migration('revert',ok=False)
sql('SELECT cron.alter_job(cron_job_id,command=>cron_command,active=>false) FROM structs.timescale_portal_workaround WHERE cron_job_id IS NOT NULL')
migration('revert')
print('PASS verification and rollback reject a modified cron command')
