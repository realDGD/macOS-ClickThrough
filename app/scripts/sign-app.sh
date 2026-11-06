#!/bin/bash
set -euo pipefail
if [[ $# -ne 1 || "$1" != /* || "$1" != */ClickThrough.app || ! -d "$1" || -L "$1" ]]; then
  echo "用法：sign-app.sh /绝对路径/ClickThrough.app" >&2
  exit 2
fi
clickthrough_app="$1"
clickthrough_identity="${CLICKTHROUGH_SIGN_IDENTITY:--}"
clickthrough_stable="${CLICKTHROUGH_STABLE_ADHOC_IDENTITY:-0}"
case "$clickthrough_stable" in 0|1) ;; *) echo "CLICKTHROUGH_STABLE_ADHOC_IDENTITY 只能为 0 或 1" >&2; exit 2 ;; esac
if [[ "$clickthrough_stable" == 1 && "$clickthrough_identity" != - ]]; then
  echo "固定 ad-hoc 身份不能与证书签名同时启用。" >&2
  exit 2
fi
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$clickthrough_app/Contents/Info.plist")" == local.clickthrough.app ]]
if /bin/ps -axo comm= | /usr/bin/awk -v target="$clickthrough_app/Contents/MacOS/ClickThrough" '$0 == target { found = 1 } END { exit !found }'; then
  echo "请先退出目标应用，再修改它的签名。" >&2
  exit 1
fi
clickthrough_arguments=(--force --options runtime --sign "$clickthrough_identity")
if [[ "$clickthrough_stable" == 1 ]]; then
  # 仅固定升级身份，不认证签名者；初次迁移仍需用户重新授权。
  clickthrough_arguments+=(--requirements '=designated => identifier "local.clickthrough.app"')
fi
/usr/bin/codesign "${clickthrough_arguments[@]}" "$clickthrough_app"
/usr/bin/codesign --verify --strict "$clickthrough_app"
if [[ "$clickthrough_stable" == 1 ]]; then
  clickthrough_requirement="$(/usr/bin/codesign --display --requirements - "$clickthrough_app" 2>&1 | /usr/bin/sed -n '/^designated => /p')"
  [[ "$clickthrough_requirement" == 'designated => identifier "local.clickthrough.app"' ]]
  /usr/bin/codesign --verify --strict --test-requirement '=identifier "local.clickthrough.app"' "$clickthrough_app"
fi
