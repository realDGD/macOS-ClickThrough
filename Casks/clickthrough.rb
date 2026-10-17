cask "clickthrough" do
  version '0.1.3'
  sha256 '7178685703859b9db381521aa5cb486f541652228d30dd7dc3f52d885894cc13'

  url 'https://github.com/realDGD/macOS-ClickThrough/releases/download/v0.1.3/ClickThrough-0.1.3-arm64.dmg'
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
