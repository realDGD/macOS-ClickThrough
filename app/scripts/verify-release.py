#!/usr/bin/env python3
"""Check public release integrity and privacy without installing or launching the app."""
import argparse
import hashlib
import json
import plistlib
import re
import os
import subprocess
import sys
from pathlib import Path

from release_cask import render_cask
from release_dmg import mounted_dmg

REPOSITORY = 'https://github.com/realDGD/macOS-ClickThrough'
REQUIRED_FILES = {
    'Contents/MacOS/ClickThrough', 'Contents/Info.plist',
    'Contents/Resources/AppIcon.icns', 'Contents/Resources/LICENSE',
    'Contents/Resources/THIRD_PARTY_NOTICES.md',
    'Contents/Resources/ThirdParty/Lucide-LICENSE.txt',
    'Contents/_CodeSignature/CodeResources',
}
PERSONAL_PATH = re.compile(rb'/(?:Users|home)/[^/\x00\s]+')
CREDENTIAL = re.compile(
    rb'BEGIN (?:[A-Z ]+ )?PRIVATE KEY|gh[pousr]_[A-Za-z0-9]{20,}'
    rb'|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}'
    rb'|sk-(?:proj-)?[A-Za-z0-9_-]{24,}')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(directory, tag, source_commit=None, native=False):
    match = re.fullmatch(r'v(\d+\.\d+\.\d+)', tag)
    require(match, 'tag must be vMAJOR.MINOR.PATCH')
    version = match.group(1)
    manifest = json.loads((directory / 'release.json').read_text())
    require(manifest['version'] == version, 'tag and packaged version differ')
    require(manifest['arch'] == 'arm64', 'release must contain arm64 only')
    require(manifest['minimum_macos'] == '14.0', 'unexpected minimum macOS version')
    commit = manifest.get('source_commit')
    require(isinstance(commit, str) and re.fullmatch(r'[0-9a-f]{40}', commit),
            'release must record a full source commit')
    if source_commit:
        require(commit == source_commit, 'source commit differs from requested source')
    name = f'ClickThrough-{version}-arm64.dmg'
    require(manifest['archive'] == name, 'unexpected archive filename')
    url = f'{REPOSITORY}/releases/download/{tag}/{name}'
    require(manifest['url'] == url and manifest['homepage'] == REPOSITORY,
            'release URL or homepage differs from the project repository')
    expected_assets = {name, name + '.sha256', 'release.json', 'clickthrough.rb'}
    require({p.name for p in directory.iterdir()} == expected_assets,
            'unexpected file in public release directory')
    digest = hashlib.sha256((directory / name).read_bytes()).hexdigest()
    require(digest == manifest['sha256'], 'archive SHA-256 differs from manifest')
    require((directory / (name + '.sha256')).read_text().strip() == f'{digest}  {name}',
            'SHA-256 sidecar differs from archive')
    cask = (directory / 'clickthrough.rb').read_text()
    require(cask == render_cask(version, digest, url, REPOSITORY),
            'Cask differs from the trusted release template')
    for path in directory.iterdir():
        if path.name != name:
            require(not PERSONAL_PATH.search(path.read_bytes()), 'personal path in release metadata')
            require(not CREDENTIAL.search(path.read_bytes()), 'credential in release metadata')
    with mounted_dmg(directory / name) as volume:
        require({p.name for p in volume.iterdir()} == {'ClickThrough.app', 'Applications'},
                'unexpected disk image contents')
        applications = volume / 'Applications'
        require(applications.is_symlink() and os.readlink(applications) == '/Applications',
                'unexpected Applications shortcut')
        app = volume / 'ClickThrough.app'
        require(app.is_dir() and not app.is_symlink(), 'expected a regular application bundle')
        seen = set()
        for path in app.rglob('*'):
            require(not path.is_symlink(), 'unexpected symlink in application')
            if path.is_dir():
                continue
            require(path.is_file(), 'unexpected application file type')
            relative = path.relative_to(app).as_posix()
            seen.add(relative)
            require(relative in REQUIRED_FILES, f'unexpected archive file: {relative}')
            payload = path.read_bytes()
            require(not PERSONAL_PATH.search(payload), f'personal path in {relative}')
            require(not CREDENTIAL.search(payload), f'credential in {relative}')
        require(seen == REQUIRED_FILES, 'required application resource missing')
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        require(info['CFBundleShortVersionString'] == version, 'bundle version differs from tag')
        require(info['LSMinimumSystemVersion'] == '14.0', 'bundle minimum macOS version differs')
        if native:
            binary = app / 'Contents/MacOS/ClickThrough'
            require(os.access(binary, os.X_OK), 'application binary is not executable')
            subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
            require(subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip() == 'arm64',
                    'unexpected Mach-O architecture')
            build = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(binary)], text=True)
            require(re.search(r'^\s*minos\s+14\.0\s*$', build, re.MULTILINE), 'unexpected Mach-O minimum version')
    return {'version': version, 'sha256': digest, 'source_commit': commit,
            'result': 'passed', 'scope': 'integrity and checked privacy patterns; no install or launch'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--source-commit')
    parser.add_argument('--native', action='store_true', help='Also verify signature, executable, Mach-O architecture and minimum macOS')
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.directory, args.tag, args.source_commit, args.native), indent=2))
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError, plistlib.InvalidFileException) as error:
        print(f'Release rejected: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
