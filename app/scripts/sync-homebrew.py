#!/usr/bin/env python3
"""Validate a published source version and update only the source-build Homebrew Cask."""
import argparse
import json
import re
import subprocess
import sys
import tarfile
from pathlib import Path

from source_cask import render_source_cask, resolve_checksum, source_url

REPOSITORY = 'realDGD/macOS-ClickThrough'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def git(tap, *args):
    return subprocess.check_output(['git', '-C', str(tap), *args], text=True).strip()


def verify_source(directory, tag, source_commit=None):
    require(re.fullmatch(r'v\d+\.\d+\.\d+', tag), 'tag must be vMAJOR.MINOR.PATCH')
    require({p.name for p in directory.iterdir()} == {'source.json', 'clickthrough.rb'},
                    'unexpected source metadata files')
    require(all(p.is_file() and not p.is_symlink() for p in directory.iterdir()),
                    'source metadata must be regular files')
    manifest = json.loads((directory / 'source.json').read_text())
    require(manifest['version'] == tag[1:], 'source version differs from tag')
    if source_commit:
        require(manifest['source_commit'] == source_commit, 'source commit differs from requested source')
    expected = render_source_cask(manifest['version'], manifest['sha256'], manifest['source_commit'])
    require(manifest['url'] == source_url(manifest['source_commit']), 'unexpected source archive URL')
    require((directory / 'clickthrough.rb').read_text() == expected,
                    'Cask differs from the trusted source template')
    return dict(manifest, result='passed')


def prepare(directory, tag):
    require(re.fullmatch(r'v\d+\.\d+\.\d+', tag), 'tag must be vMAJOR.MINOR.PATCH')
    metadata = json.loads(subprocess.check_output(
        ['gh', 'api', f'repos/{REPOSITORY}/releases/tags/{tag}'], text=True))
    require(metadata['tag_name'] == tag and metadata['draft'] is False
                    and metadata['published_at'], 'Release must already be public')
    root = Path(__file__).resolve().parents[2]
    commit = git(root, 'rev-parse', f'refs/tags/{tag}^{{commit}}')
    subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', commit, 'origin/main'], check=True)
    directory.mkdir(parents=True, exist_ok=True)
    require(not any(directory.iterdir()), 'download directory must be empty')
    digest = resolve_checksum(tag[1:], commit)
    manifest = {'version': tag[1:], 'source_commit': commit, 'sha256': digest, 'url': source_url(commit)}
    (directory / 'source.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (directory / 'clickthrough.rb').write_text(render_source_cask(tag[1:], digest, commit))
    return verify_source(directory, tag, commit)


def sync(directory, tag, source_commit, tap):
    checked = verify_source(directory, tag, source_commit)
    require(not git(tap, 'status', '--porcelain'), 'tap checkout must be clean')
    require(git(tap, 'branch', '--show-current') == 'main', 'tap must be on main')
    cask = tap / 'Casks/clickthrough.rb'
    require(cask.is_file() and not cask.is_symlink(), 'expected a regular ClickThrough Cask')
    match = re.search(r'^\s*version [\'"](\d+\.\d+\.\d+)[\'"]\s*$', cask.read_text(), re.MULTILINE)
    require(match, 'cannot determine current tap version')
    current = tuple(map(int, match.group(1).split('.')))
    candidate = tuple(map(int, checked['version'].split('.')))
    content = (directory / 'clickthrough.rb').read_bytes()
    if current == candidate:
        require(cask.read_bytes() == content, 'same version has different Cask content; publish a new version')
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
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError, tarfile.TarError) as error:
        print(f'Tap sync failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
