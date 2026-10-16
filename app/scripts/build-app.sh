#!/bin/bash
set -euo pipefail
clickthrough_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
clickthrough_build="$clickthrough_root/build"
if [[ $# -gt 0 ]]; then
  if [[ $# -ne 2 || "$1" != "--output" ]]; then
    echo "用法：build-app.sh [--output 输出目录]" >&2
    exit 2
  fi
  clickthrough_build="$2"
fi
mkdir -p "$clickthrough_build"
clickthrough_build="$(cd "$clickthrough_build" && pwd)"
if pgrep -x ClickThrough >/dev/null && [[ -e "$clickthrough_build/ClickThrough.app" ]]; then
  echo "ClickThrough 正在运行；请先退出，再覆盖已有应用，或用 --output 指定没有应用的新目录。" >&2
  exit 1
fi
swift build --package-path "$clickthrough_root" -c release > "$clickthrough_build/build.log" 2>&1 || {
  tail -n 35 "$clickthrough_build/build.log" >&2
  exit 1
}
clickthrough_bin="$(swift build --package-path "$clickthrough_root" -c release --show-bin-path)"
clickthrough_stage="$(mktemp -d "$clickthrough_build/stage.XXXXXX")"
trap 'rm -rf "$clickthrough_stage"' EXIT
clickthrough_app="$clickthrough_stage/ClickThrough.app"
mkdir -p "$clickthrough_app/Contents/MacOS" "$clickthrough_app/Contents/Resources/ThirdParty"
cp "$clickthrough_bin/ClickThrough" "$clickthrough_app/Contents/MacOS/ClickThrough"
cp "$clickthrough_root/Resources/Info.plist" "$clickthrough_app/Contents/Info.plist"
cp "$clickthrough_root/Resources/AppIcon.icns" "$clickthrough_app/Contents/Resources/AppIcon.icns"
cp "$clickthrough_root/Resources/Artwork/Lucide/LICENSE.txt" "$clickthrough_app/Contents/Resources/ThirdParty/Lucide-LICENSE.txt"
cp "$clickthrough_root/../THIRD_PARTY_NOTICES.md" "$clickthrough_app/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp "$clickthrough_root/../LICENSE" "$clickthrough_app/Contents/Resources/LICENSE"
plutil -lint "$clickthrough_app/Contents/Info.plist"
codesign --force --options runtime --sign "${CLICKTHROUGH_SIGN_IDENTITY:--}" "$clickthrough_app"
codesign --verify --strict "$clickthrough_app"
rm -rf "$clickthrough_build/ClickThrough.app"
mv "$clickthrough_app" "$clickthrough_build/ClickThrough.app"
echo "$clickthrough_build/ClickThrough.app"
