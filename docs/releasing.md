# 发布新版本

源码仓库为 [macOS-ClickThrough](https://github.com/realDGD/macOS-ClickThrough)，安装入口为 [homebrew-tap](https://github.com/realDGD/homebrew-tap)。当前流程发布 arm64、最低 macOS 14 的 **ad-hoc 签名、未公证开发版**，Release 标为 pre-release。正式 Developer ID 签名／公证流程尚未配置，不把本流程称为已公证发行。

## 1. 修改版本并通过 PR

修改 `app/Resources/Info.plist` 中的 `CFBundleShortVersionString` 和递增的 `CFBundleVersion`。例如从 `0.1.0 (3)` 更新至 `0.1.1 (4)`：

```sh
git switch -c release/v0.1.1
plutil -replace CFBundleShortVersionString -string 0.1.1 app/Resources/Info.plist
plutil -replace CFBundleVersion -string 4 app/Resources/Info.plist
```

提交改动并创建 PR。等待两组 CI 通过、审查完成后合入 main。更新发布说明，但不要上传本机正在运行的包；工作流会从提交源码重新构建。

## 2. 打版本 tag

回到最新 main，确认工作区干净后：

```sh
git switch main
git pull --ff-only
git tag -a v0.1.1 -m 'ClickThrough 0.1.1'
git push origin v0.1.1
```

[Release 工作流](../.github/workflows/release.yml) 会检查 tag 与 Info.plist 版本一致、源码属于 main 历史，再运行测试、构建、打包和脱敏检查，最后创建 **draft pre-release**。工作流不会自动公开，也不会修改 tap 或本机应用。

如果工作流因临时故障没有创建草稿，可在 Actions 里重新运行，或手动选择 Release 工作流并输入已有 tag。同名 Release 已存在时不覆盖；先在 GitHub 检查已有草稿，不使用覆盖参数替换已公开资源。

## 3. 检查草稿并公开

在 GitHub 的 Releases 中打开草稿，确认版本、来源提交和发布说明。四个附件应为：

- `ClickThrough-版本-arm64.zip`
- 对应的 `.zip.sha256`
- `release.json`（版本、源码提交、平台和归档 SHA-256；`published: false` 描述打包时状态，不代替 GitHub 当前发布状态）
- `clickthrough.rb`（指向同一份 ZIP 的 Cask）

可用已登录的 GitHub CLI 下载草稿附件再检查：

```sh
gh release download v0.1.1 --repo realDGD/macOS-ClickThrough --dir app/verification/release-v0.1.1
python3 app/scripts/verify-release.py --directory app/verification/release-v0.1.1 --tag v0.1.1
```

检查器核对版本、来源提交格式、SHA-256、归档资源及个人路径／凭据模式；工作流另对解压后的应用验签并核对架构、执行权限和最低部署版本。它们不替代 GUI 与辅助功能的实际验收。

确认后点击 **Publish release**，或执行：

```sh
gh release edit v0.1.1 --repo realDGD/macOS-ClickThrough --draft=false --prerelease
```

当前开发版保留 pre-release 标记和未公证说明。不要移动已公开 tag、替换同版本 ZIP 或重新计算 Cask 指向另一份 ZIP；需要修正时发布新版本。

## 4. 更新 Homebrew tap

发布完成、公开 URL 可以下载且 SHA-256 一致后，在 `homebrew-tap` 仓库将附件 `clickthrough.rb` 原样复制为 `Casks/clickthrough.rb`，提交并推送。不要手工猜测校验值，也不要重新压缩 ZIP。tap 的 CI 会检查 Ruby／Cask 解析并下载归档核对 SHA-256。

发布工作流的仓库 token 不能跨仓库写入 tap，因此这一步由维护者使用自己的 Git 权限完成；本项目没有要求添加跨仓库 PAT 或公开任何签名凭据。

用户安装／升级命令见 [README](../README.md) 和 [分发说明](distribution.md)。Homebrew 只负责安装应用，不会自动允许 Gatekeeper 或辅助功能权限。若本机已有手动安装版，迁移前应先自行退出并备份；发布本身不会更新已运行实例。

## 将来采用 Developer ID

先准备有效的 Developer ID Application 证书及公证凭据，再调整签名／公证工作流：签名、提交公证并确认成功、Staple、最后打包。重新核验归档后再更新 Release 和 Cask 的签名说明。证书私钥和凭据存入 Keychain 或专用 Secrets，不进入 Git、附件或日志。

参考：[Apple 公证要求](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[Homebrew Tap Trust](https://docs.brew.sh/Tap-Trust)。
