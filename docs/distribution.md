# 分发与 Homebrew

Homebrew 下载固定完整提交的 GitHub 源码归档，并验证 SHA-256；使用本机 Swift 6 Command Line Tools 编译、写入来源凭据、以固定应用标识签名，再由标准 app artifact 安装。手动 DMG 与历史 Release 继续保留，当前 Homebrew 不下载这些预编译包。[决策与代价](../.agents/notes/implemented/process/2026-11-06-source-homebrew.md)。

## 安装、迁移与升级

需要 Apple Silicon、macOS 14 或更新系统，以及支持 Swift 6 的现代独立 CLT。安装前可用 `swift --version` 检查；缺少工具链时自行运行 `xcode-select --install`。Cask 不自动安装 Xcode、CLT 或其他软件。

```sh
brew tap --custom-remote realdgd/tap https://github.com/realDGD/macOS-ClickThrough
brew install --cask realdgd/tap/clickthrough
```

首次源码迁移仍使用应用版本 0.1.3。已有原 DMG 版用户先退出应用，再运行：

```sh
brew update
brew reinstall --cask realdgd/tap/clickthrough
```

后续新版本仍按普通升级流程，退出软件后执行 `brew update` 和 `brew upgrade --cask realdgd/tap/clickthrough`。已添加旧独立 tap 的用户先按下方步骤迁移仓库历史；已使用当前仓库的 tap 无需重置。

来源凭据位于 `ClickThrough.app/Contents/Resources/HomebrewSource.plist`，包含版本、完整提交、源码归档 SHA-256、构建方式与签名策略；不写入本机源码路径。构建完成后清理下载归档中的 Swift 编译缓存，不启动应用或注册登录项。

源码安装使用 identifier-only ad-hoc 身份；它只校验应用标识，不认证签名者。首次从旧哈希身份迁移可能需要用户重新关联辅助功能授权。源码编译、授权和 Apple 公证分别处理，不承诺所有系统无需安全提示，也不修改 Gatekeeper、quarantine 或 TCC。

卸载前在应用中关闭登录启动，再执行 `brew uninstall --cask realdgd/tap/clickthrough`。不使用 `--zap` 时保留偏好与日志；只有显式 `--zap` 才清理这些本地数据，不自动清空系统权限记录。

## 旧独立 tap 迁移

仅针对已添加旧 `realdgd/tap` 的用户。以下先完整备份 tap 的 Git 历史、本地改动及未跟踪文件，再改变远程并将该 tap 的源码切换为项目仓库。**会重置该 tap 的本地改动，请保留备份。** 不卸载、替换或启动已安装应用。

```sh
(
set -e
clickthrough_tap_path="$(brew --repository realdgd/tap)"
clickthrough_tap_backup="$(mktemp -d "$HOME/ClickThrough-tap-backup.XXXXXX")"
ditto "$clickthrough_tap_path" "$clickthrough_tap_backup/tap"
brew tap --custom-remote realdgd/tap https://github.com/realDGD/macOS-ClickThrough
brew update-reset "$clickthrough_tap_path"
printf 'Tap backup: %s\n' "$clickthrough_tap_backup/tap"
)
```

`update-reset` 接收的是保存的仓库路径，不是 tap 名称；不要省略路径，否则会重置更多 Homebrew 仓库。无需运行 `brew untap`，它可能要求卸载已安装的 Cask。迁移来源后，实际升级应用仍按上文先退出 ClickThrough，再执行 `brew update`／`brew upgrade`。

## 本地 DMG

按 [开发指南](development.md) 构建新目录候选包，再打包选定的应用：

```sh
make package APP=app/build/review-candidate/ClickThrough.app
```

归档、`.dmg.sha256` 和 `release.json` 输出到应用旁的 `release/`。DMG 内含 `ClickThrough.app` 与指向 `/Applications` 的快捷方式；系统工具创建压缩只读映像，不安装额外打包软件。输出目录应是本次构建专用目录，不覆盖旧公开包或历史证据。

不提供发布地址时不生成公开 Cask，并移除输出目录残留的旧 `clickthrough.rb`。生成 Cask 时同时传入真实 HTTPS 发布 URL、项目主页及完整源码提交，例如：

```sh
python3 app/scripts/package-release.py \
  --app app/build/review-candidate/ClickThrough.app \
  --source-commit FULL_SOURCE_COMMIT \
  --url 'https://github.com/realDGD/macOS-ClickThrough/releases/download/vVERSION/ClickThrough-VERSION-arm64.dmg' \
  --homepage https://github.com/realDGD/macOS-ClickThrough
```

上面的大写值是占位，须替换为真实版本与提交。Cask 声明 arm64 与 macOS Sonoma，仅接受最低版本为 14.0 的应用。发布后工作流校验四附件，再仅提交本仓库 `Casks/clickthrough.rb`；不重新压缩或替换同版本文件。具体步骤见 [发布指南](releasing.md)。

## 正式签名发行

Developer ID 与 Apple 公证尚未配置。以后采用时，先签名应用、按 Apple 流程公证并 Staple，再生成最终 DMG、签名／公证映像及核验，最后计算 SHA-256，更新签名声明。DMG 生成、签名、公证、发布、安装和真实鼠标行为各自记录证据。

参考：[Homebrew 自定义 tap URL](https://docs.brew.sh/Taps)、[Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)、[Apple 分发打包](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)。
