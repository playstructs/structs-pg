"""Verify migration ACL contracts on the labelled disposable database only."""
import json
from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
CONTAINER = 'structs-v022-pg'
CHANGES = ('address-permission', 'device-metadata', 'work')


class WebappGrantCompatibilityTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        inspect = subprocess.run(['docker', 'inspect', CONTAINER], check=True, capture_output=True, text=True)
        labels = json.loads(inspect.stdout)[0]['Config']['Labels'] or {}
        if labels.get('structs.task') != 'v022-integration':
            raise RuntimeError('This test requires the labelled disposable integration database')

    def verify(self, change, superuser=False, setup='', expected=True):
        source = (ROOT / 'verify' / ('role-structs-webapp-20261030-' + change + '.sql')).read_text()
        # All role attributes/ACL mutations are transactional and rolled back,
        # including when a negative verification makes psql exit early.
        source = source.replace('BEGIN;', 'BEGIN;\nALTER ROLE structs_webapp ' +
            ('SUPERUSER' if superuser else 'NOSUPERUSER') + ';\n' + setup, 1)
        result = subprocess.run(['docker', 'exec', '-i', '--user', 'structs', CONTAINER,
            'psql', '-X', '-v', 'ON_ERROR_STOP=1', '-d', 'structs'], input=source,
            capture_output=True, text=True)
        if expected:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, 'Unexpectedly accepted an incorrect grant')
            self.assertIn('ERROR:', result.stderr)

    def test_deployed_grants_pass_with_legacy_and_restricted_service_roles(self):
        for superuser in (False, True):
            for change in CHANGES:
                with self.subTest(superuser=superuser, change=change):
                    self.verify(change, superuser)

    def test_explicit_write_grants_remain_rejected(self):
        cases = [('address-permission', 'UPDATE', 'structs.permission'),
                 ('device-metadata', 'DELETE', 'structs.player_address_meta'),
                 ('device-metadata', 'INSERT', 'structs.player_address_activity'),
                 ('device-metadata', 'UPDATE', 'view.address_inventory'),
                 ('work', 'INSERT', 'view.work'), ('work', 'UPDATE', 'structs.api_work')]
        for superuser in (False, True):
            for change, privilege, relation in cases:
                for grantee in ('structs_webapp', 'PUBLIC'):
                    with self.subTest(superuser=superuser, change=change, relation=relation, grantee=grantee):
                        self.verify(change, superuser, f'GRANT {privilege} ON {relation} TO {grantee};', False)

    def test_legacy_superuser_cannot_hide_missing_explicit_read_grants(self):
        for change, relation in [('address-permission', 'structs.permission'),
                                 ('device-metadata', 'structs.player_address_activity'), ('work', 'view.work')]:
            with self.subTest(change=change):
                self.verify(change, True, f'REVOKE SELECT ON {relation} FROM structs_webapp;', False)

    def test_restricted_role_cannot_inherit_write_access(self):
        self.verify('address-permission', False,
            'CREATE ROLE webapp_grant_test_group; GRANT UPDATE ON structs.permission TO webapp_grant_test_group; '
            'GRANT webapp_grant_test_group TO structs_webapp;', False)


if __name__ == '__main__':
    unittest.main()
