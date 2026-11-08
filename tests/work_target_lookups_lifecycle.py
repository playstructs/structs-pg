"""Check work-refresh deploy/revert identity and metadata on a disposable DB."""
import argparse
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--container', required=True)
args = parser.parse_args()
label = subprocess.check_output(
    ['docker', 'inspect', '--format', '{{index .Config.Labels "structs.task"}}', args.container],
    text=True).strip()
if label != 'v022-integration':
    raise RuntimeError('A labelled disposable v022-integration database is required')
root = Path(__file__).resolve().parent.parent
name = 'function-api-work-20261108-target-lookups'


def body(direction, change=name):
    source = (root / direction / (change + '.sql')).read_text()
    return source.split('BEGIN;\n', 1)[1].rsplit('COMMIT;', 1)[0]


# Reversal must be the prior deployment, including its function comment.
assert body('revert') == body('deploy', 'function-api-work-20260924-empty-queue-fast-path')
source = '''BEGIN;
CREATE TEMP TABLE work_refresh_metadata AS
SELECT oid,proowner,proacl,proconfig,prosrc FROM pg_proc
WHERE oid='structs.api_work_refresh(bigint,timestamptz)'::regprocedure;
'''
source += body('revert')
source += '''
DO $$ BEGIN
    IF (SELECT prosrc FROM pg_proc WHERE oid='structs.api_work_refresh(bigint,timestamptz)'::regprocedure)
       LIKE '%CROSS JOIN LATERAL%' THEN RAISE EXCEPTION 'revert retained new query'; END IF;
END $$;
'''
source += body('deploy')
source += '''
DO $$ BEGIN
    IF EXISTS (
        (SELECT oid,proowner,proacl,proconfig,prosrc FROM work_refresh_metadata
         EXCEPT SELECT oid,proowner,proacl,proconfig,prosrc FROM pg_proc
         WHERE oid='structs.api_work_refresh(bigint,timestamptz)'::regprocedure)
    ) THEN RAISE EXCEPTION 'revert/redeploy changed function identity, metadata or source'; END IF;
END $$;
ROLLBACK;
'''
result = subprocess.run(
    ['docker', 'exec', '-i', '--user', 'structs', '-e', 'PGHOST=/var/run/postgresql',
     args.container, 'psql', '-Xq', '-v', 'ON_ERROR_STOP=1', '-d', 'structs'],
    input=source, capture_output=True, text=True)
if result.returncode:
    raise AssertionError(result.stdout + result.stderr)
print('PASS: exact prior-function revert and redeploy preserve OID, owner, grants, configuration and source')
