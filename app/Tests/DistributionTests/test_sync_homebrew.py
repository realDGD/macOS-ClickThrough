#!/usr/bin/env python3
"""Exercise tap updates with real temporary Git repositories, without installing apps."""
import json
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

import test_verify_release as fixtures

SCRIPT = Path(__file__).resolve().parents[2] / 'scripts/sync-homebrew.py'


class TapSyncTests(unittest.TestCase):
    def setUp(self):
        fixture = fixtures.ReleaseVerificationTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        fixture.fixture()
        self.assets = fixture.output
        self.remote = self.assets.parent / (self.assets.name + '-remote.git')
        self.tap = self.assets.parent / (self.assets.name + '-tap')
        self.addCleanup(shutil.rmtree, self.remote, ignore_errors=True)
        self.addCleanup(shutil.rmtree, self.tap, ignore_errors=True)
        self.git('init', '--quiet', '--bare', '--initial-branch=main', str(self.remote), cwd=self.assets)
        self.git('clone', '--quiet', str(self.remote), str(self.tap), cwd=self.assets)
        self.git('config', 'user.name', 'Test Maintainer')
        self.git('config', 'user.email', 'test@example.invalid')
        (self.tap / 'Casks').mkdir()
        self.cask = self.tap / 'Casks/clickthrough.rb'
        self.cask.write_text('cask "clickthrough" do\n  version \'0.0.9\'\nend\n')
        (self.tap / 'README.md').write_text('Unrelated tap content\n')
        self.commit()

    def git(self, *args, cwd=None):
        return subprocess.check_output(['git', *args], cwd=cwd or self.tap,
                                       text=True, stderr=subprocess.DEVNULL).strip()

    def commit(self):
        self.git('add', '.')
        self.git('commit', '--quiet', '-m', 'Fixture')
        self.git('push', '--quiet', 'origin', 'HEAD:main')

    def sync(self, commit='a' * 40):
        return subprocess.run([sys.executable, str(SCRIPT), 'sync', '--directory', str(self.assets),
                               '--tag', 'v0.1.1', '--source-commit', commit, '--tap', str(self.tap)],
                              capture_output=True, text=True)

    def test_new_version_pushes_only_the_cask(self):
        before = self.git('rev-parse', 'HEAD')
        result = self.sync()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['result'], 'updated')
        self.assertEqual(self.cask.read_bytes(), (self.assets / 'clickthrough.rb').read_bytes())
        self.assertEqual(self.git('diff', '--name-only', before, 'HEAD'), 'Casks/clickthrough.rb')
        self.assertEqual(self.git('rev-parse', 'HEAD'), self.git('--git-dir', str(self.remote), 'rev-parse', 'main'))

    def test_identical_version_makes_no_commit(self):
        self.cask.write_bytes((self.assets / 'clickthrough.rb').read_bytes())
        self.commit()
        before = self.git('rev-parse', 'HEAD')
        result = self.sync()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['result'], 'unchanged')
        self.assertEqual(self.git('rev-parse', 'HEAD'), before)

    def test_older_release_cannot_downgrade_the_tap(self):
        self.cask.write_text('cask "clickthrough" do\n  version \'0.10.0\'\nend\n')
        self.commit()
        before = self.git('rev-parse', 'HEAD')
        result = self.sync()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['result'], 'skipped-older')
        self.assertEqual(self.git('rev-parse', 'HEAD'), before)

    def test_same_version_with_changed_content_is_rejected(self):
        self.cask.write_bytes((self.assets / 'clickthrough.rb').read_bytes() + b'# changed\n')
        self.commit()
        before = self.git('rev-parse', 'HEAD')
        result = self.sync()
        self.assertEqual(result.returncode, 1)
        self.assertIn('same version', result.stderr)
        self.assertEqual(self.git('rev-parse', 'HEAD'), before)

    def test_wrong_source_commit_cannot_update_tap(self):
        before = self.git('rev-parse', 'HEAD')
        result = self.sync(commit='b' * 40)
        self.assertEqual(result.returncode, 1)
        self.assertIn('source commit', result.stderr)
        self.assertEqual(self.git('rev-parse', 'HEAD'), before)

    def test_unrelated_local_changes_cannot_enter_the_commit(self):
        (self.tap / 'README.md').write_text('Local change\n')
        self.git('add', 'README.md')
        before = self.git('rev-parse', 'HEAD')
        result = self.sync()
        self.assertEqual(result.returncode, 1)
        self.assertIn('clean', result.stderr)
        self.assertEqual(self.git('rev-parse', 'HEAD'), before)


if __name__ == '__main__':
    unittest.main()
