# 发布新版本

源码仓库为 [macOS-ClickThrough](https://github.com/realDGD/macOS-ClickThrough)，安装 Cask 位于 [本仓库](../Casks/clickthrough.rb)。从 v0.1.1 起，当前流程发布 DMG：arm64、最低 macOS 14 的 **ad-hoc 签名、未公证开发版**，Release 标为 pre-release。正式 Developer ID 签名／公证流程尚未配置，不把本流程称为已公证发行。

## 1. 修改版本并通过 PR

修改 `app/Resources/Info.plist` 中的 `CFBundleShortVersionString` 和递增的 `CFBundleVersion`。例如从 `0.1.1 (4)` 更新至 `0.1.2 (5)`：

```sh
git switch -c release/v0.1.2
plutil -replace CFBundleShortVersionString -string 0.1.2 app/Resources/Info.plist
plutil -replace CFBundleVersion -string 5 app/Resources/Info.plist
```

提交改动并创建 PR。等待两组 CI 通过、审查完成后合入 main。更新发布说明，但不要上传本机正在运行的包；工作流会从提交源码重新构建。

## 2. 打版本 tag

回到最新 main，确认工作区干净后：

```sh
git switch main
git pull --ff-only
git tag -a v0.1.2 -m 'ClickThrough 0.1.2'
git push origin v0.1.2
```

[Release 工作流](../.github/workflows/release.yml) 会检查 tag 与 Info.plist 版本一致、源码属于 main 历史，再运行测试、构建、打包和脱敏检查，最后创建 **draft pre-release**。工作流不会自动公开，也不会修改 tap 或本机应用。

如果工作流因临时故障没有创建草稿，可在 Actions 里重新运行，或手动选择 Release 工作流并输入已有 tag。同名 Release 已存在时不覆盖；先在 GitHub 检查已有草稿，不使用覆盖参数替换已公开资源。

## 3. 检查草稿并公开

在 GitHub 的 Releases 中打开草稿，确认版本、来源提交和发布说明。四个附件应为：

- `ClickThrough-版本-arm64.dmg`
- 对应的 `.dmg.sha256`
- `release.json`（版本、源码提交、平台和归档 SHA-256；`published: false` 描述打包时状态，不代替 GitHub 当前发布状态）
- `clickthrough.rb`（指向同一份 DMG 的 Cask）

可用已登录的 GitHub CLI 下载草稿附件再检查：

```sh
gh release download v0.1.2 --repo realDGD/macOS-ClickThrough --dir app/verification/release-v0.1.2
python3 app/scripts/verify-release.py --directory app/verification/release-v0.1.2 --tag v0.1.2 --native
```

检查器核对版本、来源提交格式、SHA-256、归档资源及个人路径／凭据模式；`--native` 在只读挂载时对应用验签并核对架构、执行权限和最低部署版本。它们不替代 GUI 与辅助功能的实际验收。

确认后点击 **Publish release**，或执行：

```sh
gh release edit v0.1.2 --repo realDGD/macOS-ClickThrough --draft=false --prerelease
```

当前开发版保留 pre-release 标记和未公证说明。不要移动已公开 tag、替换同版本 DMG 或重新计算 Cask 指向另一份 DMG；需要修正时发布新版本。

## 4. 自动更新本仓库 Cask

公开 Release 后，[Sync Homebrew Cask 工作流](../.github/workflows/sync-homebrew.yml) 下载四个附件，核对 tag 对应的 main 历史提交、DMG 完整性、内容白名单、脱敏模式与完整 Cask 模板；只读挂载检查应用签名、执行权限、arm64 和最低系统，再通过 Homebrew DSL 解析，最后仅更新本仓库 `Casks/clickthrough.rb`。草稿不触发，pre-release 同样更新，无需手动复制。

版本按数字比较：相同版本相同内容不产生提交，旧版本不能覆盖新版，同版本内容不同则失败。远程并发改动导致普通推送失败时，检查 main 后重跑；不 force push。同步使用当前仓库内置 `GITHUB_TOKEN` 的 `contents: write` 权限，不配置个人 token、Deploy Key 或额外 Secret。

GitHub 内置 token 的推送通常不会再次触发 CI，因此原生校验和 Cask DSL 检查在同步 job 内、提交前执行。手动 main 提交和 PR 仍运行常规 macOS 15／26 CI。不要把未触发的后续 CI 描述为已通过。

恢复入口为 Actions → **Sync Homebrew Cask** → **Run workflow**，选择 `main`，输入已公开的 DMG tag；也可执行：

```sh
gh workflow run sync-homebrew.yml --repo realDGD/macOS-ClickThrough --ref main -f tag=v0.1.2
```

查看摘要确认 `updated`、`unchanged` 或 `skipped-older`。这一步不创建／公开 Release。若以后改为在 Action 内使用内置 token 自动公开草稿，必须显式 dispatch 同步工作流；当前由维护者通过网页或个人 CLI 公开。

### 已公开版本和旧入口

`v0.1.0` 的 tag、四个 ZIP 时代附件与历史记录保持不变；它不进入新的 DMG 校验／同步流程。本次通过新 `v0.1.1 (4)` 提供 DMG，不给旧版本替换同名资源。旧独立 tap 保留迁移说明，旧 Cask 不再接受自动更新；新安装和既有用户换源命令见 [分发说明](distribution.md)。旧跨仓库专用公钥及 `HOMEBREW_TAP_DEPLOY_KEY` Secret 在迁移中撤销。

用户安装／升级命令见 [README](../README.md) 和 [分发说明](distribution.md)。Homebrew 只负责安装应用，不会自动允许 Gatekeeper 或辅助功能权限。若本机已有手动安装版，迁移前应先自行退出并备份；发布本身不会更新已运行实例。

## 将来采用 Developer ID

先准备有效的 Developer ID Application 证书及公证凭据，再调整签名／公证工作流：签名、提交公证并确认成功、Staple、最后生成 DMG。重新核验归档后再更新 Release 和 Cask 的签名说明。证书私钥和凭据存入 Keychain 或专用 Secrets，不进入 Git、附件或日志。

参考：[GitHub Release 事件](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#release)、[GITHUB_TOKEN 范围与事件限制](https://docs.github.com/en/actions/concepts/security/github_token)、[Deploy Key 权限](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys)、[Apple 公证要求](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[Homebrew Tap Trust](https://docs.brew.sh/Tap-Trust)。
