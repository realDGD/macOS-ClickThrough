#!/usr/bin/env python3
"""Public-release integrity and privacy checks; no app installation or launch."""
import hashlib
import json
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[2] / 'scripts/verify-release.py'
sys.path.insert(0, str(SCRIPT.parent))
from release_cask import render_cask

REPOSITORY = 'https://github.com/realDGD/macOS-ClickThrough'


class ReleaseVerificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='clickthrough-release-check-')
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name)

    def fixture(self, binary=b'release executable', extra=None):
        name = 'ClickThrough-0.1.1-arm64.dmg'
        files = {
            'Contents/MacOS/ClickThrough': binary,
            'Contents/Info.plist': plistlib.dumps({
                'CFBundleShortVersionString': '0.1.1', 'LSMinimumSystemVersion': '14.0',
            }),
            'Contents/Resources/AppIcon.icns': b'icon',
            'Contents/Resources/LICENSE': b'GNU AFFERO GENERAL PUBLIC LICENSE',
            'Contents/Resources/THIRD_PARTY_NOTICES.md': b'Lucide ISC',
            'Contents/Resources/ThirdParty/Lucide-LICENSE.txt': b'ISC license',
            'Contents/_CodeSignature/CodeResources': b'signature manifest',
        }
        files.update(extra or {})
        with tempfile.TemporaryDirectory(prefix='clickthrough-dmg-fixture-') as temporary:
            stage = Path(temporary)
            for path, data in files.items():
                target = stage / 'ClickThrough.app' / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
            (stage / 'Applications').symlink_to('/Applications', target_is_directory=True)
            subprocess.run(['hdiutil', 'create', '-quiet', '-nospotlight', '-fs', 'HFS+',
                            '-format', 'UDZO', '-volname', 'ClickThrough', '-srcfolder', str(stage),
                            str(self.output / name)], check=True)
        digest = hashlib.sha256((self.output / name).read_bytes()).hexdigest()
        url = f'{REPOSITORY}/releases/download/v0.1.1/{name}'
        (self.output / (name + '.sha256')).write_text(f'{digest}  {name}\n')
        (self.output / 'release.json').write_text(json.dumps({
            'version': '0.1.1', 'arch': 'arm64', 'minimum_macos': '14.0',
            'archive': name, 'sha256': digest, 'url': url, 'homepage': REPOSITORY,
            'source_commit': 'a' * 40,
        }))
        (self.output / 'clickthrough.rb').write_text(
            render_cask('0.1.1', digest, url, REPOSITORY))

    def run_check(self, tag='v0.1.1'):
        return subprocess.run([sys.executable, str(SCRIPT), '--directory', str(self.output),
                               '--tag', tag], capture_output=True, text=True)

    def test_valid_release(self):
        self.fixture()
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_tag_must_match_packaged_version(self):
        self.fixture()
        result = self.run_check('v0.2.0')
        self.assertEqual(result.returncode, 1)
        self.assertIn('version', result.stderr)

    def test_tampered_download_is_rejected(self):
        self.fixture()
        with (self.output / 'ClickThrough-0.1.1-arm64.dmg').open('ab') as stream:
            stream.write(b'tampered')
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn('SHA-256', result.stderr)

    def test_personal_paths_inside_binary_are_rejected(self):
        self.fixture(binary=b'/' + b'Users/private_user/private_project/source.swift')
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn('personal path', result.stderr)

    def test_credentials_inside_binary_are_rejected(self):
        self.fixture(binary=('gh' + 'p_' + 'a' * 36).encode())
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn('credential', result.stderr)

    def test_unexpected_diagnostic_file_is_rejected(self):
        self.fixture(extra={'Contents/Resources/session.jsonl': b'private diagnostic'})
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn('unexpected', result.stderr)

    def test_cask_with_extra_ruby_is_rejected(self):
        self.fixture()
        with (self.output / 'clickthrough.rb').open('a') as stream:
            stream.write('system("unexpected command")\n')
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn('Cask', result.stderr)


if __name__ == '__main__':
    unittest.main()
