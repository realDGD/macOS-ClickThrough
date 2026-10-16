#!/usr/bin/env python3
"""Public-release integrity and privacy checks; no app installation or launch."""
import hashlib
import json
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[2] / 'scripts/verify-release.py'
REPOSITORY = 'https://github.com/realDGD/macOS-ClickThrough'


class ReleaseVerificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='clickthrough-release-check-')
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name)

    def fixture(self, binary=b'release executable', extra=None):
        name = 'ClickThrough-0.1.0-arm64.zip'
        files = {
            'Contents/MacOS/ClickThrough': binary,
            'Contents/Info.plist': plistlib.dumps({
                'CFBundleShortVersionString': '0.1.0', 'LSMinimumSystemVersion': '14.0',
            }),
            'Contents/Resources/AppIcon.icns': b'icon',
            'Contents/Resources/LICENSE': b'GNU AFFERO GENERAL PUBLIC LICENSE',
            'Contents/Resources/THIRD_PARTY_NOTICES.md': b'Lucide ISC',
            'Contents/Resources/ThirdParty/Lucide-LICENSE.txt': b'ISC license',
            'Contents/_CodeSignature/CodeResources': b'signature manifest',
        }
        files.update(extra or {})
        with zipfile.ZipFile(self.output / name, 'w') as archive:
            for path, data in files.items():
                archive.writestr('ClickThrough.app/' + path, data)
        digest = hashlib.sha256((self.output / name).read_bytes()).hexdigest()
        url = f'{REPOSITORY}/releases/download/v0.1.0/{name}'
        (self.output / (name + '.sha256')).write_text(f'{digest}  {name}\n')
        (self.output / 'release.json').write_text(json.dumps({
            'version': '0.1.0', 'arch': 'arm64', 'minimum_macos': '14.0',
            'archive': name, 'sha256': digest, 'url': url, 'homepage': REPOSITORY,
            'source_commit': 'a' * 40,
        }))
        (self.output / 'clickthrough.rb').write_text(
            f'cask "clickthrough" do\n  version \'0.1.0\'\n'
            f'  sha256 \'{digest}\'\n  url \'{url}\'\nend\n')

    def run_check(self, tag='v0.1.0'):
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
        with (self.output / 'ClickThrough-0.1.0-arm64.zip').open('ab') as stream:
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


if __name__ == '__main__':
    unittest.main()
