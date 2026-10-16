#!/bin/bash
set -euo pipefail
probe_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
probe_sdk="$(xcrun --show-sdk-path)"
probe_names=("$@")
if [ "${#probe_names[@]}" = 0 ]; then probe_names=(Probe Target); fi
for probe_name in "${probe_names[@]}"; do
  case "$probe_name" in Probe|Target) ;; *) exit 2 ;; esac
  probe_app="${FIRST_CLICK_BUILD_DIR:-$probe_root/build}/FirstClick$probe_name.app"
  mkdir -p "$probe_app/Contents/MacOS"
  if [ "$probe_name" = Probe ]; then
    xcrun swiftc -swift-version 6 -sdk "$probe_sdk" -target arm64-apple-macos27.0 \
      "$probe_root/ActivationPolicy.swift" "$probe_root/Probe.swift" -emit-executable -o "$probe_app/Contents/MacOS/FirstClick$probe_name"
  else
    xcrun swiftc -swift-version 6 -sdk "$probe_sdk" -target arm64-apple-macos27.0 \
      "$probe_root/$probe_name.swift" -o "$probe_app/Contents/MacOS/FirstClick$probe_name"
  fi
  python3 - "$probe_app" "$probe_name" <<'PY'
from pathlib import Path
import plistlib,sys
app=Path(sys.argv[1]);name='FirstClick'+sys.argv[2]
version='3' if sys.argv[2]=='Probe' else '1'
metadata={'CFBundleExecutable':name,'CFBundleIdentifier':'local.clickthrough.firstclick'+sys.argv[2].lower(),
          'CFBundleName':name,'CFBundlePackageType':'APPL','CFBundleVersion':version,
          'CFBundleShortVersionString':'0.0.'+version,'LSMinimumSystemVersion':'27.0',
          'NSHighResolutionCapable':True}
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(metadata))
PY
  codesign --force --sign - "$probe_app"
  codesign --verify --strict "$probe_app"
done
