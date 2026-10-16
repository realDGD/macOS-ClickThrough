cask "clickthrough" do
  version '0.1.1'
  sha256 '540df8249649662cecce202def31c8b598997ea9271d8dd5f8b5e8428e52f5ad'

  url 'https://github.com/realDGD/macOS-ClickThrough/releases/download/v0.1.1/ClickThrough-0.1.1-arm64.dmg'
  name "ClickThrough"
  desc "Menu bar utility for first-click interaction with background windows"
  homepage 'https://github.com/realDGD/macOS-ClickThrough'

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "ClickThrough.app"

  uninstall quit: "local.clickthrough.app"

  zap trash: [
    "~/Library/Preferences/local.clickthrough.app.plist",
    "~/Library/Logs/ClickThrough",
  ]

  caveats <<~EOS
    This development build is ad-hoc signed and has not been notarized by Apple.
    macOS may block its first launch; updates may require re-adding Accessibility permission.
    Enable Accessibility for ClickThrough in System Settings, then turn it on.
    Before uninstalling, turn off launch at login in ClickThrough settings.
  EOS
end
