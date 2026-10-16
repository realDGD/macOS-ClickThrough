#!/usr/bin/env python3
"""Isolated release regression scenarios; run directly with python3 after building the app."""
import hashlib
import argparse
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / 'scripts'))
from release_dmg import mounted_dmg
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--homebrew', action='store_true', help='Validate Cask DSL with an already-installed Homebrew; never installs or registers a tap')
parser.add_argument('--app', type=Path, help='Built app to copy into the isolated fixture; defaults to app/build/ClickThrough.app')
args = parser.parse_args()
records = []
with tempfile.TemporaryDirectory(prefix='clickthrough-distribution-') as temp_name:
    fixture = Path(temp_name)
    (fixture/'scripts').mkdir()
    (fixture/'build').mkdir()
    for name in ('package-release.py', 'release_cask.py'):
        shutil.copy2(root/'scripts'/name, fixture/'scripts'/name)
    app = fixture/'candidate/ClickThrough.app'
    shutil.copytree(args.app or root/'build/ClickThrough.app', app)
    # A fixture-specific minimum catches a packager that hardcodes the old target.
    info = app/'Contents/Info.plist'
    metadata = plistlib.loads(info.read_bytes())
    fixture_version = metadata['CFBundleShortVersionString']
    metadata['LSMinimumSystemVersion'] = '14.0'
    info.write_bytes(plistlib.dumps(metadata))
    subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True, capture_output=True)
    script = fixture/'scripts/package-release.py'

    def run(*args):
        return subprocess.run(['python3', str(script), '--app', str(app), *args], capture_output=True, text=True)

    for arguments in [('--url', 'https://release.example.invalid/archive.dmg'),
                      ('--url', 'http://release.example.invalid/archive.dmg', '--homepage', 'https://project.example.invalid')]:
        result = run(*arguments)
        assert result.returncode == 2, result.stdout + result.stderr
        assert not (app.parent/'release').exists(), 'Invalid inputs produced a release directory'
    records.append({'case': 'invalid_args', 'result': 'pass', 'side_effects': 'no release directory'})

    # The running old package may coexist with a new candidate; never advertise it as macOS 14.
    metadata['LSMinimumSystemVersion'] = '27.0'
    info.write_bytes(plistlib.dumps(metadata))
    result = run('--url', 'https://release.example.invalid/archive.dmg', '--homepage', 'https://project.example.invalid')
    assert result.returncode == 2 and 'selected app requires 27.0' in result.stderr
    assert not (app.parent/'release').exists()
    metadata['LSMinimumSystemVersion'] = '14.0'
    info.write_bytes(plistlib.dumps(metadata))
    subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True, capture_output=True)
    records.append({'case': 'old_app_not_advertised_as_macos14', 'result': 'pass'})

    result = run('--url', 'https://release.example.invalid/archive.dmg', '--homepage', 'https://project.example.invalid')
    assert result.returncode == 0, result.stdout + result.stderr
    output = app.parent/'release'
    manifest = json.loads((output/'release.json').read_text())
    assert manifest['minimum_macos'] == '14.0', 'Release minimum differs from the selected app'
    digest = hashlib.sha256((output/manifest['archive']).read_bytes()).hexdigest()
    assert digest == manifest['sha256'] and digest in (output/'clickthrough.rb').read_text()
    subprocess.run(['/usr/bin/ruby', '-c', str(output/'clickthrough.rb')], check=True, capture_output=True)
    with mounted_dmg(output / manifest['archive']) as volume:
        assert {p.name for p in volume.iterdir()} == {'ClickThrough.app', 'Applications'}
        assert (volume / 'Applications').is_symlink()
        assert os.readlink(volume / 'Applications') == '/Applications'
        subprocess.run(['codesign', '--verify', '--strict', str(volume / 'ClickThrough.app')], check=True)
        assert os.access(volume / 'ClickThrough.app/Contents/MacOS/ClickThrough', os.X_OK)
        assert plistlib.loads((volume / 'ClickThrough.app/Contents/Info.plist').read_bytes())['CFBundleShortVersionString'] == fixture_version
    records.append({'case': 'dmg_contents_signature_cask_hash_and_syntax', 'result': 'pass'})

    if args.homebrew:
        brew = shutil.which('brew')
        assert brew, '--homebrew requires an already-installed brew'
        ruby = '''require "cask/cask_loader"; require "json"
c = Cask::CaskLoader.load(File.read(ARGV.fetch(0)))
puts JSON.generate({token:c.token,version:c.version.to_s,sha256:c.sha256,
  macos:c.depends_on.macos.minimum_version.to_s,comparator:c.depends_on.macos.comparator,
  arch:c.depends_on.arch})'''
        loaded = subprocess.run([brew, 'ruby', '-e', ruby, '--', str(output/'clickthrough.rb')],
                                capture_output=True, text=True,
                                env=dict(os.environ, HOMEBREW_NO_AUTO_UPDATE='1', HOMEBREW_NO_ANALYTICS='1'))
        assert loaded.returncode == 0, loaded.stderr
        definition = json.loads(loaded.stdout)
        assert definition['macos'] == '14' and definition['comparator'] == '>='
        assert definition['sha256'] == digest and definition['version'] == fixture_version
        records.append({'case': 'current_homebrew_dsl', 'result': 'pass', 'parsed': definition})

    # A local package after a previously generated public Cask must not advertise stale publication metadata.
    info = app/'Contents/Info.plist'
    metadata = plistlib.loads(info.read_bytes())
    major, minor, patch = map(int, fixture_version.split('.'))
    next_version = f'{major}.{minor}.{patch + 1}'
    metadata['CFBundleShortVersionString'] = next_version
    info.write_bytes(plistlib.dumps(metadata))
    subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True, capture_output=True)
    result = run()
    assert result.returncode == 0, result.stdout + result.stderr
    manifest = json.loads((output/'release.json').read_text())
    assert manifest['version'] == next_version and manifest['url'] is None
    assert not (output/'clickthrough.rb').exists(), 'FAIL: public Cask survives a newer local package'
    records.append({'case': 'local_package_removes_stale_cask', 'result': 'pass'})

print(json.dumps({'cases': records, 'failures': 0, 'scope': 'temporary signed fixture; no installed app/tap changes'}, indent=2))
