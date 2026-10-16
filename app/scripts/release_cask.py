"""Trusted Cask template shared by packaging and release validation."""


def ruby_string(value):
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def render_cask(version, digest, url, homepage):
    return f'''cask "clickthrough" do
  version {ruby_string(version)}
  sha256 {ruby_string(digest)}

  url {ruby_string(url)}
  name "ClickThrough"
  desc "Menu bar utility for first-click interaction with background windows"
  homepage {ruby_string(homepage)}

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
'''
