#!/usr/bin/env python3
"""Package the already-built app; optionally produce a Homebrew Cask for a supplied release URL."""
import argparse
import hashlib
import json
import plistlib
import re
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlparse


from release_cask import render_cask


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", help="HTTPS URL where the resulting DMG will be published")
    parser.add_argument("--homepage", help="Public project homepage (required with --url)")
    parser.add_argument("--app", type=Path, help="Built .app to package; output goes to its sibling release directory")
    parser.add_argument("--source-commit", help="Full source commit recorded in the public release manifest")
    args = parser.parse_args()
    if args.source_commit and not re.fullmatch(r'[0-9a-f]{40}', args.source_commit):
        parser.error("--source-commit must be a full lowercase 40-character Git commit")
    if bool(args.url) != bool(args.homepage):
        parser.error("--url and --homepage must be supplied together")
    for value in (args.url, args.homepage):
        if value and (urlparse(value).scheme != "https" or not urlparse(value).netloc):
            parser.error("release and homepage URLs must use HTTPS")

    root = Path(__file__).resolve().parents[1]
    app = (args.app or root / "build/ClickThrough.app").resolve()
    with (app / "Contents/Info.plist").open("rb") as stream:
        metadata = plistlib.load(stream)
    minimum_macos = metadata["LSMinimumSystemVersion"]
    if args.url and minimum_macos != "14.0":
        parser.error(f"Cask targets macOS 14; selected app requires {minimum_macos}. Rebuild or select the matching --app.")
    subprocess.run(["codesign", "--verify", "--strict", str(app)], check=True)
    binary = app / "Contents/MacOS/ClickThrough"
    arch = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).strip().replace(" ", "-")
    version = metadata["CFBundleShortVersionString"]
    output = app.parent / "release"
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"ClickThrough-{version}-{arch}.dmg"
    with tempfile.TemporaryDirectory(prefix='clickthrough-dmg-stage-') as temporary:
        stage = Path(temporary)
        subprocess.run(['ditto', '--norsrc', '--noextattr', str(app), str(stage / 'ClickThrough.app')], check=True)
        (stage / 'Applications').symlink_to('/Applications', target_is_directory=True)
        subprocess.run(['hdiutil', 'create', '-quiet', '-nospotlight', '-fs', 'HFS+', '-format', 'UDZO',
                        '-volname', 'ClickThrough', '-srcfolder', str(stage), str(archive)], check=True)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / (archive.name + ".sha256")).write_text(f"{digest}  {archive.name}\n")
    manifest = dict(version=version, arch=arch, archive=archive.name, sha256=digest,
                    minimum_macos=minimum_macos, signing="Run codesign -dv to inspect the built identity",
                    published=False, url=args.url, homepage=args.homepage, source_commit=args.source_commit)
    (output / "release.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if args.url:
        if arch != "arm64":
            parser.error("the initial Cask supports the validated arm64 build only")
        cask = render_cask(version, digest, args.url, args.homepage)
        (output / "clickthrough.rb").write_text(cask)
    else:
        # A local-only package must not leave a Cask for an older public archive.
        (output / "clickthrough.rb").unlink(missing_ok=True)
    print(archive)
    print(f"SHA-256: {digest}")
    if args.url:
        print(output / "clickthrough.rb")
        print("Cask generated; upload this exact archive before publishing the tap.")
    else:
        print("No public Cask generated: supply --url and --homepage after selecting release hosting.")


if __name__ == "__main__":
    main()
