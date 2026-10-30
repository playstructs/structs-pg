"""Exercise migration metadata and failure atomicity on a labelled disposable DB."""
import argparse
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--container', default='structs-v022-pg')
args = parser.parse_args()
label = subprocess.check_output(['docker', 'inspect', '--format', '{{index .Config.Labels "structs.task"}}', args.container], text=True).strip()
if label != 'v022-integration':
    raise RuntimeError('A labelled disposable v022-integration database is required')
root = Path(__file__).resolve().parent.parent


def body(direction):
    source = (root / direction / 'table-work-20261030-uint64.sql').read_text()
    return source.replace('BEGIN;\n', '', 1).rsplit('COMMIT;', 1)[0]


def sql(source, failure=None):
    result = subprocess.run(['docker', 'exec', '-i', '--user', 'structs', '-e', 'PGHOST=/var/run/postgresql', args.container,
                             'psql', '-X', '-v', 'ON_ERROR_STOP=1', '-d', 'structs'], input=source, capture_output=True, text=True)
    if failure:
        if result.returncode == 0 or failure not in result.stderr:
            raise AssertionError(result.stdout + result.stderr)
    elif result.returncode:
        raise AssertionError(result.stdout + result.stderr)


# Explicitly exercise a non-migrator view owner, per-column grant options,
# default grants introduced only after the original objects existed, and
# disabled/replica trigger state. Everything, including the roles, rolls back.
metadata = """
CREATE ROLE work_uint64_owner;
CREATE ROLE work_uint64_reader;
CREATE ROLE work_uint64_default;
GRANT USAGE,CREATE ON SCHEMA view TO work_uint64_owner;
GRANT USAGE ON SCHEMA structs TO work_uint64_owner;
GRANT SELECT ON structs.api_work TO work_uint64_owner;
ALTER VIEW view.work OWNER TO work_uint64_owner;
SET LOCAL ROLE work_uint64_owner;
GRANT SELECT (block_start) ON view.work TO work_uint64_reader WITH GRANT OPTION;
RESET ROLE;
ALTER VIEW view.work SET (security_barrier=true);
COMMENT ON VIEW view.work IS 'retained work view';
COMMENT ON COLUMN view.work.block_start IS 'exact clock';
ALTER TABLE structs.struct_attribute DISABLE TRIGGER api_work_dirty_upd;
ALTER TABLE structs.planet_attribute ENABLE REPLICA TRIGGER api_work_dirty_upd;
ALTER DEFAULT PRIVILEGES IN SCHEMA view GRANT SELECT ON TABLES TO work_uint64_default;
"""
check = """
DO $$
BEGIN
    IF (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid='view.work'::regclass)<>'work_uint64_owner'
        OR (SELECT reloptions FROM pg_class WHERE oid='view.work'::regclass)<>ARRAY['security_barrier=true']
        OR obj_description('view.work'::regclass)<>'retained work view'
        OR (SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='view.work'::regclass AND attname='block_start')<>'exact clock'
        OR NOT has_column_privilege('work_uint64_reader','view.work','block_start','SELECT WITH GRANT OPTION')
        OR has_table_privilege('work_uint64_default','view.work','SELECT')
        OR NOT has_table_privilege('structs_webapp','view.work','SELECT')
        OR (SELECT tgenabled FROM pg_trigger WHERE tgrelid='structs.struct_attribute'::regclass AND tgname='api_work_dirty_upd')<>'D'
        OR (SELECT tgenabled FROM pg_trigger WHERE tgrelid='structs.planet_attribute'::regclass AND tgname='api_work_dirty_upd')<>'R'
    THEN RAISE EXCEPTION 'view/trigger metadata changed'; END IF;
END $$;
"""
sql('BEGIN;\n' + metadata + body('revert') + check + 'DROP TABLE work_uint64_views,work_uint64_columns,work_uint64_triggers;' + body('deploy') + check + 'ROLLBACK;')
print('PASS: revert/deploy preserve owner, view options/comments, column ACL/grant options, effective grants and trigger state')
sql("BEGIN; INSERT INTO structs.planet_attribute(id,object_id,object_type,attribute_type,val) VALUES('0-2-990980','2-990980','planet','planetaryShield',18446744073709551615);\n" + body('revert'),
    'work or attribute value exceeds integer')
print('PASS: reversal refuses wide stored values without changing persistent state')
sql('BEGIN; CREATE VIEW view.work_uint64_dependent AS SELECT * FROM view.work;\n' + body('revert'),
    'other objects depend on them')
print('PASS: unknown dependent view blocks replacement instead of being dropped')
sql((root / 'verify' / 'table-work-20261030-uint64.sql').read_text())
print('PASS: deployed uint64 contract remains intact after refused reversals')
