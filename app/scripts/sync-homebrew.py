#!/usr/bin/env python3
"""Validate a public Release and update only the ClickThrough Cask in a checked-out tap."""
import argparse
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location('verify_release', Path(__file__).with_name('verify-release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
REPOSITORY = 'realDGD/macOS-ClickThrough'


def git(tap, *args):
    return subprocess.check_output(['git', '-C', str(tap), *args], text=True).strip()


def prepare(directory, tag):
    release.require(re.fullmatch(r'v\d+\.\d+\.\d+', tag), 'tag must be vMAJOR.MINOR.PATCH')
    metadata = json.loads(subprocess.check_output(
        ['gh', 'api', f'repos/{REPOSITORY}/releases/tags/{tag}'], text=True))
    release.require(metadata['tag_name'] == tag and metadata['draft'] is False
                    and metadata['published_at'], 'Release must already be public')
    name = f'ClickThrough-{tag[1:]}-arm64.zip'
    assets = {name, name + '.sha256', 'release.json', 'clickthrough.rb'}
    release.require({asset['name'] for asset in metadata['assets']} == assets,
                    'Release must contain exactly the four expected assets')
    root = Path(__file__).resolve().parents[2]
    commit = git(root, 'rev-parse', f'refs/tags/{tag}^{{commit}}')
    subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', commit, 'origin/main'], check=True)
    directory.mkdir(parents=True, exist_ok=True)
    release.require(not any(directory.iterdir()), 'download directory must be empty')
    command = ['gh', 'release', 'download', tag, '--repo', REPOSITORY, '--dir', str(directory)]
    for asset in sorted(assets):
        command.extend(['--pattern', asset])
    subprocess.run(command, check=True)
    return release.verify(directory, tag, commit)


def sync(directory, tag, source_commit, tap):
    checked = release.verify(directory, tag, source_commit)
    release.require(not git(tap, 'status', '--porcelain'), 'tap checkout must be clean')
    release.require(git(tap, 'branch', '--show-current') == 'main', 'tap must be on main')
    cask = tap / 'Casks/clickthrough.rb'
    release.require(cask.is_file() and not cask.is_symlink(), 'expected a regular ClickThrough Cask')
    match = re.search(r'^\s*version [\'"](\d+\.\d+\.\d+)[\'"]\s*$', cask.read_text(), re.MULTILINE)
    release.require(match, 'cannot determine current tap version')
    current = tuple(map(int, match.group(1).split('.')))
    candidate = tuple(map(int, checked['version'].split('.')))
    content = (directory / 'clickthrough.rb').read_bytes()
    if current == candidate:
        release.require(cask.read_bytes() == content, 'same version has different Cask content; publish a new version')
        result = 'unchanged'
    elif current > candidate:
        result = 'skipped-older'
    else:
        cask.write_bytes(content)
        git(tap, 'add', '--', 'Casks/clickthrough.rb')
        git(tap, '-c', 'user.name=ClickThrough Release Automation',
            '-c', 'user.email=release-automation@users.noreply.github.com',
            'commit', '-m', f'Update clickthrough to {tag}')
        # A concurrent remote change fails safely: never force push or overwrite it.
        git(tap, 'push', 'origin', 'HEAD:refs/heads/main')
        result = 'updated'
    if result != 'updated':
        # Exercise the receive-pack authorization even for an idempotent validation run.
        git(tap, 'push', '--dry-run', 'origin', 'HEAD:refs/heads/main')
    return dict(checked, result=result, tap_commit=git(tap, 'rev-parse', 'HEAD'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    for name in ('prepare', 'sync'):
        command = commands.add_parser(name)
        command.add_argument('--directory', type=Path, required=True)
        command.add_argument('--tag', required=True)
        if name == 'sync':
            command.add_argument('--source-commit', required=True)
            command.add_argument('--tap', type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == 'prepare':
            result = prepare(args.directory, args.tag)
        else:
            result = sync(args.directory, args.tag, args.source_commit, args.tap)
        print(json.dumps(result, indent=2))
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f'Tap sync failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
