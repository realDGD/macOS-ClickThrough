cask "clickthrough" do
  version '0.1.4'
  sha256 '356765e850391352793f617eeb01a937cc8c119222cb344d2bfe5dd24a9e2193'

  url 'https://github.com/realDGD/macOS-ClickThrough/archive/eb2a471d2d14e970b6013229cbbc37f9582a25ee.tar.gz'
  name "ClickThrough"
  desc "Menu bar utility compiled locally with Swift Command Line Tools"
  homepage 'https://github.com/realDGD/macOS-ClickThrough'

  depends_on arch: :arm64
  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: ['-c', 'set -euo pipefail
[[ -d "$DEVELOPER_DIR" ]] || { echo "Install Swift 6 Command Line Tools first." >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c \'Print :CFBundleShortVersionString\' app/Resources/Info.plist)" == "$1" ]] || { echo "Cask/source version mismatch" >&2; exit 1; }
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
/usr/libexec/PlistBuddy -c \'Add :builder string clt-source-cask\' "$clickthrough_stamp"
/usr/libexec/PlistBuddy -c \'Add :signingPolicy string identifier-only-adhoc-v1\' "$clickthrough_stamp"
bash app/scripts/sign-app.sh "$clickthrough_app"
', 'clickthrough-source-build', '0.1.4', 'eb2a471d2d14e970b6013229cbbc37f9582a25ee', '356765e850391352793f617eeb01a937cc8c119222cb344d2bfe5dd24a9e2193'],
                      chdir: 'macOS-ClickThrough-eb2a471d2d14e970b6013229cbbc37f9582a25ee', print_stdout: true,
                      env: { "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }
  end

  app 'macOS-ClickThrough-eb2a471d2d14e970b6013229cbbc37f9582a25ee/app/build/homebrew/ClickThrough.app'

  postflight_steps do
    remove ['macOS-ClickThrough-eb2a471d2d14e970b6013229cbbc37f9582a25ee/app/.build', 'macOS-ClickThrough-eb2a471d2d14e970b6013229cbbc37f9582a25ee/app/.swiftpm'], recursive: true
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
