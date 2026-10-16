#!/bin/bash
set -euo pipefail
background_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
background_app="$background_root/build/BackgroundButtonProbe.app"
mkdir -p "$background_app/Contents/MacOS"
xcrun swiftc -swift-version 6 -target arm64-apple-macos27.0 \
  "$background_root/Gate.swift" "$background_root/Probe.swift" \
  -o "$background_app/Contents/MacOS/BackgroundButtonProbe"
python3 - "$background_app" <<'PY'
from pathlib import Path
import plistlib,sys
app=Path(sys.argv[1])
(app/'Contents/Info.plist').write_bytes(plistlib.dumps({
 'CFBundleExecutable':'BackgroundButtonProbe','CFBundleIdentifier':'local.clickthrough.backgroundbuttonprobe',
 'CFBundleName':'BackgroundButtonProbe','CFBundlePackageType':'APPL','CFBundleVersion':'1',
 'CFBundleShortVersionString':'0.0.1','LSMinimumSystemVersion':'27.0','NSHighResolutionCapable':True}))
PY
codesign --force --sign - "$background_app"
codesign --verify --strict "$background_app"
