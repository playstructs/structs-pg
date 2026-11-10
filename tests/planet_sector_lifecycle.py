"""Verify planet-sector migration deploy, read contract and revert on a disposable DB."""
import argparse
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--container', required=True)
args = parser.parse_args()
label = subprocess.check_output(
    ['docker', 'inspect', '--format', '{{index .Config.Labels "structs.task"}}', args.container],
    text=True).strip()
if label != 'sector-integration':
    raise RuntimeError('A labelled disposable sector-integration database is required')
root = Path(__file__).resolve().parent.parent
change = 'planet-sector-20261110'


def body(direction):
    source = (root / direction / (change + '.sql')).read_text()
    return source.split('BEGIN;\n', 1)[1].rsplit('COMMIT;', 1)[0]


# Run against a DB with the migration deployed; all changes roll back.
source = 'BEGIN;\n' + body('revert') + '''
INSERT INTO structs.planet(id,name) VALUES('2-999811','Legacy sector fixture');
GRANT SELECT ON view.planet TO structs_webapp;
CREATE TEMP TABLE planet_view_before AS
SELECT oid,relowner,relacl FROM pg_class WHERE oid='view.planet'::regclass;
'''
source += body('deploy') + '''
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM structs.planet WHERE id='2-999811' AND sector=0)
    THEN RAISE EXCEPTION 'existing planet did not default to unassigned'; END IF;
    IF EXISTS (SELECT oid,relowner,relacl FROM planet_view_before EXCEPT
               SELECT oid,relowner,relacl FROM pg_class WHERE oid='view.planet'::regclass)
    THEN RAISE EXCEPTION 'deploy changed view identity/owner/grants'; END IF;
END $$;
UPDATE structs.planet SET sector=127 WHERE id='2-999811';
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM view.planet WHERE planet_id='2-999811' AND sector=127)
    THEN RAISE EXCEPTION 'view did not expose sector'; END IF;
    BEGIN
        UPDATE structs.planet SET sector=45 WHERE id='2-999811';
        RAISE EXCEPTION 'invalid sector accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END $$;
'''
# Revert uses a temp ACL snapshot; remove the first snapshot before repeating it.
source += 'DROP TABLE planet_sector_view_acl;\n' + body('revert') + '''
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema IN ('structs','view') AND table_name='planet' AND column_name='sector')
    THEN RAISE EXCEPTION 'revert retained sector'; END IF;
    IF NOT has_table_privilege('structs_webapp','view.planet','SELECT')
    THEN RAISE EXCEPTION 'revert lost existing view grant'; END IF;
END $$;
'''
source += body('deploy') + 'ROLLBACK;\n'
result = subprocess.run(
    ['docker', 'exec', '-i', '-e', 'PGHOST=127.0.0.1', '-e', 'PGUSER=postgres',
     args.container, 'psql', '-Xq', '-v', 'ON_ERROR_STOP=1', '-d', 'structs'],
    input=source, capture_output=True, text=True)
if result.returncode:
    raise AssertionError(result.stdout + result.stderr)
print('PASS: legacy default, view readback, constraint, deploy identity/grants, revert and redeploy')
