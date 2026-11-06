# 发布指南

源码仓库与 Homebrew tap 共用 [macOS-ClickThrough](https://github.com/realDGD/macOS-ClickThrough)。当前 [Cask](../Casks/clickthrough.rb) 固定源码归档，用户在本机使用独立 CLT 编译安装；手动 DMG 草稿及历史附件保留。版本发布、Cask 更新和本机安装分别记录结果。

## 1. 准备版本与源码

修改 `app/Resources/Info.plist` 的 `CFBundleShortVersionString`，递增 `CFBundleVersion`。应用版本使用数字三段格式。按正常 PR 流程合入 main，通过相关 CI，再为这一源码提交创建 `vMAJOR.MINOR.PATCH` 标签。不要给旧标签替换源码或附件，也不要将本机正在运行的包作为发布产物。

新来源提交必须包含 `app/scripts/build-app.sh`、`app/scripts/sign-app.sh` 和匹配版本的应用资源。首次从 DMG 转为源码 Cask 的 0.1.3 是一次安装方式迁移，固定已合并的 `3e60ffd386f93445787f898eab9d4f7f263c65d4`，旧用户执行一次重装；之后遵守新版本更新规则。

## 2. 构建与公开 Release

[Release 工作流](../.github/workflows/release.yml) 在 tag 推送或手动选择已有 tag 时运行相关检查，构建并验证手动 DMG，创建 pre-release 草稿。审阅具体版本、源码提交和附件后再公开；创建源码标签不等于已公开发行。

手动 DMG 仍为 ad-hoc 签名、未公证开发版。附件保留 DMG、其 SHA-256、`release.json` 和 DMG 兼容 Cask 清单；后者用于这套归档的历史完整性验证，不是当前仓库 Homebrew 安装入口。不要把源码归档 checksum 当作 DMG checksum。

## 3. 自动更新源码 Cask

公开 Release 后，[Sync Homebrew Cask 工作流](../.github/workflows/sync-homebrew.yml)读取公开 Release，解析 tag 的真实提交，并确认它属于 main 历史。随后下载该完整提交的 GitHub 源码归档，核对归档中的版本、应用标识及必需构建入口，计算实际 SHA-256。

`app/scripts/source_cask.py` 单点生成源码 Cask。准备目录只包含 `source.json` 和 `clickthrough.rb`；同步前核对固定 URL、版本、完整提交、校验值、可信模板和真实 Homebrew DSL。工作流只使用仓库内置 `GITHUB_TOKEN` 更新 `Casks/clickthrough.rb`，不需要跨仓库密钥或个人 token。

新版本按数字比较；同版本同内容不提交，旧版本不能降级，同版本不同来源或内容被拒绝。并发远端变更导致普通推送失败，检查 main 后重跑，不 force push。不要将手动 DMG 的 Cask 附件直接覆盖源码入口。

独立核对已公开源码并生成本地候选 Cask：

```sh
python3 app/scripts/source_cask.py \
  --version VERSION --source-commit FULL_SOURCE_COMMIT \
  --output app/verification/clickthrough-source-candidate.rb
```

占位值须替换为真实数字版本及完整提交；生成器会下载固定来源，检查版本并计算 checksum。需要修改公开 Cask 时使用独立 PR 或上述受控同步流程，不将检查目录中的候选视为已发布。

## 4. 用户安装与验收

用户命令见 [README](../README.md) 与[分发说明](distribution.md)。Homebrew 使用已安装的现代 Swift 6 CLT，编译后写入来源凭据并采用固定标识 ad-hoc 签名。它不认证开发者，不等于 Developer ID 或 Apple 公证，也不会自动授予辅助功能权限。

确认 CI、本地构建、远端 Cask 安装和实际业务时分别报告；不把其中一个自动记为其他项目通过。不额外安装软件或扩大真实应用矩阵。

## Developer ID 与公证

目前没有配置 Developer ID、公证或 Staple。以后调整时，先准备有效证书及公证凭据，再单独修改相应分发流程。签名材料存入 Keychain 或专用 Secrets，不进入源码、附件或日志。

参考：[Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)、[Apple 公证要求](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)。
