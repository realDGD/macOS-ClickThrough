# 分发与 Homebrew

从 v0.1.1 起，通过 [GitHub Releases](https://github.com/realDGD/macOS-ClickThrough/releases) 分发 arm64 DMG，最低 macOS 14。[Cask](../Casks/clickthrough.rb) 放在同一项目仓库；Homebrew 与手动下载使用同一个 DMG 和 SHA-256。已公开的 v0.1.0 tag、ZIP 和附件保留原样，历史结果见 [首版发布验证](validation/RELEASE_0_1_0_2026_10_16.md)。

## 安装、迁移与升级

```sh
brew tap --custom-remote realdgd/tap https://github.com/realDGD/macOS-ClickThrough
brew install --cask realdgd/tap/clickthrough
```

显式 URL 让项目仓库同时作为 tap，`realdgd/tap` 是保留的本地 tap 名称。`--custom-remote` 既用于首次添加，也能将旧独立 tap 的来源切换到项目仓库，不需要改包名。该命令会下载 tap 源码，不安装或替换应用；随后只有显式安装／升级才更改应用。不要只执行旧的一行安装命令来期待 Homebrew 自动猜出新来源。

完整安装命令仅信任该 Cask，不要求信任整个 tap，参见 [Homebrew Tap Trust](https://docs.brew.sh/Tap-Trust)。原独立 `homebrew-tap` 保留迁移说明和历史版本，不再同步新发行；原 `homebrew-cask` 上游 fork 保持不变。

手动安装：打开 DMG，将应用拖入“应用程序”，完成复制后推出磁盘映像。已有手动安装版本时，迁移到 Homebrew 前先自行退出并备份，避免覆盖运行中的应用。

升级前退出 ClickThrough，再运行：

```sh
brew update
brew upgrade --cask realdgd/tap/clickthrough
```

卸载前先在应用中关闭登录启动，再执行 `brew uninstall --cask realdgd/tap/clickthrough`。只有显式 `--zap` 才清理偏好与日志；不宣称能自动清空 macOS TCC 记录。

当前仍为 ad-hoc 签名、未公证开发版，macOS 可能阻止首次打开，更新后可能需要重新添加辅助功能权限。请审阅系统提示后自行决定是否允许。DMG 不改变签名／公证状态；安装流程不关闭 Gatekeeper、不移除 quarantine、不自动授予权限。

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
