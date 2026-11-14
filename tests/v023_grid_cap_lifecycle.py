"""Run the v0.23 grid migration lifecycle in a new, disposable PostgreSQL cluster.

PG_BIN must point to a directory containing initdb, pg_ctl and psql.
This uses a focused schema fixture; it is not a full TimescaleDB stack rehearsal.
"""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
bin_dir = Path(os.environ['PG_BIN'])
change = 'grid-connection-capacity-maximum-20261114'

with tempfile.TemporaryDirectory(prefix='structs-v023-') as tmp:
    data = Path(tmp) / 'data'
    subprocess.run([str(bin_dir / 'initdb'), '-D', str(data), '-A', 'trust', '-U', 'structs'],
                   check=True, stdout=subprocess.DEVNULL)
    subprocess.run([str(bin_dir / 'pg_ctl'), '-D', str(data), '-l', str(Path(tmp) / 'server.log'),
                    '-o', f"-h '' -k {tmp}", 'start'], check=True, stdout=subprocess.DEVNULL)
    try:
        def sql(source, expected_error=None):
            result = subprocess.run([str(bin_dir / 'psql'), '-X', '-h', tmp, '-U', 'structs',
                                     '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'],
                                    input=source, text=True, capture_output=True)
            if expected_error:
                assert result.returncode and expected_error in result.stderr, result.stdout + result.stderr
            elif result.returncode:
                raise AssertionError(result.stdout + result.stderr)

        def script(direction):
            return (root / direction / (change + '.sql')).read_text()

        sql('''CREATE SCHEMA structs; CREATE SCHEMA cache;
CREATE TABLE structs.player_object(object_id text, player_id text);
CREATE TABLE structs.planet(id text, owner text);
''' + (root / 'deploy/table-grid.sql').read_text() + '''
ALTER TABLE structs.grid ALTER COLUMN attribute_type SET NOT NULL;
INSERT INTO structs.grid(id,attribute_type,object_type,object_id,val)
VALUES('15-4-999824','wrong','substation','4-999824',9007199254740993);
''' + (root / 'deploy/function-unit-display-format.sql').read_text()
            + (root / 'deploy/trigger-grass-grid.sql').read_text())
        sql(script('deploy'))
        sql(script('verify'))
        sql("""DO $$ BEGIN
IF NOT EXISTS(SELECT 1 FROM structs.grid WHERE id='15-4-999824'
AND attribute_type='connectionCapacityMaximum' AND val=9007199254740993) THEN
RAISE EXCEPTION 'backfill lost value'; END IF; END $$;""")
        sql((root / 'tests/v023-grid-cap.sql').read_text())
        for value in ('-1', '1.5', '18446744073709551616', 'NULL'):
            sql(f"UPDATE structs.grid SET val={value} WHERE id='15-4-999824';",
                'grid_connection_capacity_maximum_uint64')
        sql(script('revert'), 'cannot revert connectionCapacityMaximum')
        sql(script('verify'))
        sql("DELETE FROM structs.grid WHERE id='15-4-999824';")
        sql(script('revert'))
        sql(script('deploy'))
        sql(script('verify'))
        print('PASS: deploy, label repair, exact uint64, zero/delete, replay, invalid-value refusal, guarded revert and redeploy')
    finally:
        subprocess.run([str(bin_dir / 'pg_ctl'), '-D', str(data), '-m', 'fast', 'stop'],
                       check=True, stdout=subprocess.DEVNULL)
