# ClickThrough

[![CI](https://github.com/realDGD/macOS-ClickThrough/actions/workflows/ci.yml/badge.svg)](https://github.com/realDGD/macOS-ClickThrough/actions/workflows/ci.yml)

<img src="app/Resources/Artwork/AppIcon.png" alt="ClickThrough 应用图标" width="128">

原生 macOS 菜单栏应用，让可见后台窗口的首次点击尽可能执行原本操作。使用公开 API，保留真实鼠标事件；目标窗口会正常激活并前移。

最低部署目标为 **macOS 14 Sonoma**，当前构建为 **Apple Silicon / arm64**。已完成的实机验证来自 macOS 27；macOS 14 的实际运行效果仍待验收。[版本调整与验证记录](docs/validation/MACOS14_2026_10_15.md) 区分构建支持和实机结果。

## 安装

首次使用 Homebrew 入口：

```sh
brew tap --custom-remote realdgd/tap https://github.com/realDGD/macOS-ClickThrough
brew install --cask realdgd/tap/clickthrough
```

Homebrew 的 [Cask](Casks/clickthrough.rb) 下载固定提交及 SHA-256 的源码归档，在本机使用 **Swift 6 Command Line Tools** 编译，再安装到“应用程序”；不是下载预编译 App。安装前需要已有现代独立 CLT，可通过 `swift --version` 检查版本，缺少时自行运行 `xcode-select --install`。

已安装原 DMG 版的用户，退出 ClickThrough 后执行一次迁移：

```sh
brew update
brew reinstall --cask realdgd/tap/clickthrough
```

[GitHub Releases](https://github.com/realDGD/macOS-ClickThrough/releases) 的历史 DMG 和 ZIP 继续保留；手动安装 DMG 时将 `ClickThrough.app` 拖入“应用程序”。

已使用旧独立 `homebrew-tap` 的用户，请先按[迁移步骤](docs/distribution.md#旧独立-tap-迁移)备份并重置该 tap 的源码。两个仓库的 Git 历史不同，仅改变 URL 不足以迁移。tap 和包名保持不变，迁移源码与升级应用分别执行。

Homebrew 源码构建使用固定应用标识的 ad-hoc 签名，便于沿用后续更新授权，但不认证开发者。**本机构建仍不等于 Apple 公证或系统授权。** 首次从旧哈希身份迁移可能需要重新关联辅助功能权限；系统安全提示按正常流程处理，安装不修改 Gatekeeper。

已手动安装的用户，迁移到 Homebrew 前请先自行退出并备份现有应用。更新前也请先退出 ClickThrough，再运行：

```sh
brew update
brew upgrade --cask realdgd/tap/clickthrough
```

## 使用

- 左键点击菜单栏图标开启或关闭功能；右键打开设置和退出菜单。
- 设置支持隐藏图标、登录启动、应用黑名单和白名单。隐藏后从 Spotlight 或 Finder 重新打开软件即可恢复图标。
- 诊断支持可选详细日志，自动轮换并清理旧文件，总占用最多 20 MiB；默认关闭，设置会保留。
- 开启前需要为 ClickThrough 授予辅助功能权限。首次点击能力取决于目标应用的公开 AX 支持和事件处理，不能保证所有应用都有效。

详情见 [应用使用说明](app/README.md)；[分发说明](docs/distribution.md) 包含安装、卸载及签名限制。维护者步骤见 [发布指南](docs/releasing.md)：tag 可构建手动 DMG 草稿，公开 Release 后 Action 校验对应源码归档并更新本仓库的源码 Cask，无需跨仓库密钥。

## 开发

主要开发环境为 macOS 27，最低运行目标保持 macOS 14。构建只需提供 Swift 6 和 macOS SDK 的现代 Command Line Tools，无需完整 Xcode；已验证的工具链及要求见 [开发指南](docs/development.md)。后续新功能的版本取舍见 [平台政策](.agents/notes/implemented/architecture/2026-10-15-macos14-platform.md)。在项目根目录运行：

```sh
make help
make test
make build
```

默认产物为 `app/build/ClickThrough.app`。运行中的应用不会被覆盖；要保留现有实例，可通过 [开发指南](docs/development.md) 构建到新目录。

| 入口 | 内容 |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Agent 长期工作约束和阅读入口 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 修改范围、验证和提交准备 |
| [架构](docs/architecture.md) | 当前组件与 A4 主路径 |
| [开发指南](docs/development.md) | 构建、运行和目录约定 |
| [测试说明](docs/testing.md) | 自动检查、真实鼠标验收及未验证范围 |
| [Agent Notes](.agents/notes/README.md) | 长期决策的理由与取舍 |
| [文档目录](docs/README.md) | 当前文档、历史研究与验证记录 |
| [第三方素材声明](THIRD_PARTY_NOTICES.md) | 应用图标的 Lucide 来源与 ISC 许可 |

项目组织参考 [DeepSeek Harness 的 AGENTS.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/AGENTS.md) 和 [Agent Notes](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/README.md)，按本项目规模采用精简结构。

## 许可证

Copyright (C) 2026 realDGD。本项目原创代码采用 [GNU AGPLv3](LICENSE)（SPDX：`AGPL-3.0-only`），允许商业使用，修改和分发须遵守相应的 copyleft 与源码提供要求。第三方素材保留其原有许可证，Lucide 图标的 ISC 许可见 [第三方声明](THIRD_PARTY_NOTICES.md)。
