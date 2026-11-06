#!/usr/bin/env python3
"""Render a source Cask, optionally downloading its pinned GitHub archive to resolve SHA-256."""
import argparse
import hashlib
import plistlib
import re
import subprocess
import tarfile
import tempfile
from pathlib import Path

from release_cask import ruby_string

REPOSITORY = 'https://github.com/realDGD/macOS-ClickThrough'
BUILD = '''set -euo pipefail
[[ -d "$DEVELOPER_DIR" ]] || { echo "Install Swift 6 Command Line Tools first." >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' app/Resources/Info.plist)" == "$1" ]] || { echo "Cask/source version mismatch" >&2; exit 1; }
export CLICKTHROUGH_SIGN_IDENTITY=-
export CLICKTHROUGH_STABLE_ADHOC_IDENTITY=1
unset SDKROOT
# Homebrew supplies the outer sandbox; keep SwiftPM state inside this source tree.
swift() {
  /usr/bin/xcrun swift "$@" --disable-sandbox --cache-path "$PWD/app/.build/homebrew/cache" --config-path "$PWD/app/.build/homebrew/config" --security-path "$PWD/app/.build/homebrew/security"
}
export -f swift
bash app/scripts/build-app.sh --output app/build/homebrew
clickthrough_app="$PWD/app/build/homebrew/ClickThrough.app"
clickthrough_stamp="$clickthrough_app/Contents/Resources/HomebrewSource.plist"
/usr/bin/plutil -create xml1 "$clickthrough_stamp"
/usr/libexec/PlistBuddy -c "Add :version string $1" "$clickthrough_stamp"
/usr/libexec/PlistBuddy -c "Add :commit string $2" "$clickthrough_stamp"
/usr/libexec/PlistBuddy -c "Add :sha256 string $3" "$clickthrough_stamp"
/usr/libexec/PlistBuddy -c 'Add :builder string clt-source-cask' "$clickthrough_stamp"
/usr/libexec/PlistBuddy -c 'Add :signingPolicy string identifier-only-adhoc-v1' "$clickthrough_stamp"
bash app/scripts/sign-app.sh "$clickthrough_app"
'''


def validate(version, commit, digest=None):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('version must be numeric MAJOR.MINOR.PATCH')
    if not re.fullmatch(r'[0-9a-f]{40}', commit):
        raise ValueError('source commit must be a full lowercase Git SHA')
    if digest is not None and not re.fullmatch(r'[0-9a-f]{64}', digest):
        raise ValueError('source SHA-256 must be 64 lowercase hexadecimal characters')


def source_url(commit):
    return f'{REPOSITORY}/archive/{commit}.tar.gz'


def resolve_checksum(version, commit):
    validate(version, commit)
    with tempfile.TemporaryDirectory(prefix='clickthrough-source-') as temporary:
        archive = Path(temporary) / 'source.tar.gz'
        subprocess.run(['curl', '--fail', '--location', '--silent', '--show-error', '--retry', '2',
                        '--proto', '=https', '--tlsv1.2', source_url(commit), '--output', str(archive)], check=True)
        prefix = f'macOS-ClickThrough-{commit}/'
        with tarfile.open(archive) as source:
            for name in ('app/scripts/build-app.sh', 'app/scripts/sign-app.sh'):
                if not source.getmember(prefix + name).isfile():
                    raise ValueError(f'source archive is missing {name}')
            with source.extractfile(prefix + 'app/Resources/Info.plist') as stream:
                info = plistlib.load(stream)
            if info['CFBundleShortVersionString'] != version or info['CFBundleIdentifier'] != 'local.clickthrough.app':
                raise ValueError('source archive version or bundle identity differs')
        return hashlib.sha256(archive.read_bytes()).hexdigest()


def render_source_cask(version, digest, commit):
    validate(version, commit, digest)
    source = f'macOS-ClickThrough-{commit}'
    arguments = ', '.join(map(ruby_string, ['-c', BUILD, 'clickthrough-source-build', version, commit, digest]))
    return f'''cask "clickthrough" do
  version {ruby_string(version)}
  sha256 {ruby_string(digest)}

  url {ruby_string(source_url(commit))}
  name "ClickThrough"
  desc "Menu bar utility compiled locally with Swift Command Line Tools"
  homepage {ruby_string(REPOSITORY)}

  depends_on arch: :arm64
  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: [{arguments}],
                      chdir: {ruby_string(source)}, print_stdout: true,
                      env: {{ "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }}
  end

  app {ruby_string(source + '/app/build/homebrew/ClickThrough.app')}

  postflight_steps do
    remove [{ruby_string(source + '/app/.build')}, {ruby_string(source + '/app/.swiftpm')}], recursive: true
  end

  uninstall quit: "local.clickthrough.app"

  zap trash: [
    "~/Library/Preferences/local.clickthrough.app.plist",
    "~/Library/Logs/ClickThrough",
  ]

  caveats <<~EOS
    This cask compiles the fixed source archive locally with Swift 6 Command Line Tools.
    Source builds use identifier-only ad-hoc signing; this does not authenticate the signer.
    Migrating from older hash-bound builds may require re-authorizing Accessibility once.
    Local compilation is separate from Apple notarization and Gatekeeper approval.
    Before uninstalling, turn off launch at login in ClickThrough settings.
  EOS
end
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True)
    parser.add_argument('--source-commit', required=True)
    parser.add_argument('--sha256', help='Verified checksum; otherwise download and verify the archive')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        digest = args.sha256 or resolve_checksum(args.version, args.source_commit)
        args.output.write_text(render_source_cask(args.version, digest, args.source_commit))
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError, tarfile.TarError) as error:
        parser.exit(1, f'Source Cask rejected: {error}\n')
    print(f'{args.output}: pinned source SHA-256 {digest}')


if __name__ == '__main__':
    main()
