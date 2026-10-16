#!/usr/bin/env python3
"""Package the already-built app; optionally produce a Homebrew Cask for a supplied release URL."""
import argparse
import hashlib
import json
import plistlib
import subprocess
from pathlib import Path
from urllib.parse import urlparse


def ruby_string(value):
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", help="HTTPS URL where the resulting zip will be published")
    parser.add_argument("--homepage", help="Public project homepage (required with --url)")
    parser.add_argument("--app", type=Path, help="Built .app to package; output goes to its sibling release directory")
    args = parser.parse_args()
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
    archive = output / f"ClickThrough-{version}-{arch}.zip"
    subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive)], check=True)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / (archive.name + ".sha256")).write_text(f"{digest}  {archive.name}\n")
    manifest = dict(version=version, arch=arch, archive=archive.name, sha256=digest,
                    minimum_macos=minimum_macos, signing="Run codesign -dv to inspect the built identity",
                    published=False, url=args.url, homepage=args.homepage)
    (output / "release.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if args.url:
        if arch != "arm64":
            parser.error("the initial Cask supports the validated arm64 build only")
        cask = f'''cask "clickthrough" do
  version {ruby_string(version)}
  sha256 {ruby_string(digest)}

  url {ruby_string(args.url)}
  name "ClickThrough"
  desc "Menu bar utility for first-click interaction with background windows"
  homepage {ruby_string(args.homepage)}

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "ClickThrough.app"

  uninstall quit: "local.clickthrough.app"

  zap trash: [
    "~/Library/Preferences/local.clickthrough.app.plist",
    "~/Library/Logs/ClickThrough",
  ]

  caveats <<~EOS
    Enable Accessibility for ClickThrough in System Settings, then turn it on.
    Before uninstalling, turn off launch at login in ClickThrough settings.
  EOS
end
'''
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
