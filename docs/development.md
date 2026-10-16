# 开发指南

## 环境

项目使用 Swift 6、AppKit、SwiftUI 和系统框架，没有第三方 Swift 包依赖。macOS 27 是主要开发和验证环境，当前工具链为 Xcode 27 / Swift 6.4；最低运行目标保持 macOS 14。开发主机、SDK／编译器和最低部署版本分别管理，最低运行版本不要求使用同年代的工具链。

**无需完整 Xcode。** 本项目通过 SwiftPM 编译，使用预生成的 ICNS，再调用系统 `plutil`、`codesign` 组装应用，不依赖 `xcodebuild`、Interface Builder 或 Asset Catalog 编译。提供 Swift 6 和适配 macOS SDK 的独立 Command Line Tools 即可构建；已在 macOS 27 用 CLT 的 Swift 6.4 / SDK 27 独立构建成功。旧系统自带的旧版 CLT 不一定满足 Swift 6 要求。分发脚本和相应检查另外需要 Python 3；DMG 使用系统 `hdiutil` 创建与只读挂载，Cask DSL 检查需要已安装的 Homebrew。

安装 CLT 可使用 `xcode-select --install`。如果机器也装有 Xcode，可对单次构建指定工具目录，无需改变系统的全局选择：

```sh
DEVELOPER_DIR=/Library/Developer/CommandLineTools make build
```

构建应用和运行测试的工具要求分开看：本机 CLT 6.4 的默认 `swift test` 报告 `TestingMacros` 插件无法加载，虽然该插件文件存在。该结果不影响已通过的 `make build`；当前 CI 使用 runner 的完整 Xcode 工具链运行 Swift Testing，不把本次 CLT 测试失败记为通过。

验证范围见 [CI 与 CLT 记录](validation/CI_CLT_2026_10_16.md)；Apple 对 CLT 所含 SDK 和工具的说明见 [官方文档](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/)。

新功能优先评估当前系统的现代公开 API。遇到旧系统兼容问题时，按 [平台政策](../.agents/notes/implemented/architecture/2026-10-15-macos14-platform.md) 评估功能收益和兼容成本，再决定版本限定、必要的兼容实现或新的最低版本。当前 14 基线不预先规定未来每个功能的实现路线。

以下命令均在项目根目录执行。`make help` 列出日常入口；底层脚本也可以直接调用。

## 构建与运行

```sh
make test
make build
open app/build/ClickThrough.app
```

默认输出 `app/build/ClickThrough.app`。已有输出目录含应用且任何 ClickThrough 进程正在运行时，脚本拒绝覆盖。保留当前实例时，选择一个尚未含应用的新目录：

```sh
make build BUILD_DIR=app/build/review-candidate
```

等价脚本为 `bash app/scripts/build-app.sh --output app/build/review-candidate`。构建候选包不自动打开或替换运行实例，也不改变 TCC。检查包后需要使用新版时，先退出旧实例，再手动打开候选包；不要同时运行两份引擎。

本地默认 ad-hoc 签名，新二进制可能需要用户重新添加辅助功能授权。保持固定安装位置并使用稳定 Developer ID 是正式分发的问题，详见 [分发说明](distribution.md)。

应用图标源、生成命令及许可位置见 [素材说明](../app/Resources/Artwork/README.md)。正常构建使用已生成的 ICNS，不增加 Xcode 资源编译或下载步骤。

构建对源码路径执行编译器前缀映射，并仅在新组装的可执行副本上移除调试符号，再签名。发布前另以 [归档检查工具](../app/scripts/verify-release.py) 核对版本、SHA-256、资源白名单及个人路径／凭据模式。编译目录和原始日志仍只保留在本地；这些检查不会修改正在运行的包。

## 目录

- `app/Sources/`、`app/Tests/`：产品与相关自动检查。
- `app/Resources/Info.plist`、`app/Package.swift`：应用与部署声明。
- `app/scripts/`：构建、DMG 打包、原生校验和 Cask 更新入口。
- `Casks/clickthrough.rb`：同仓库 Homebrew 入口，由已公开 Release 自动更新。
- `app/build/`、`app/.build/`：可再生成的输出，不进入源码版本控制。
- `app/verification/`：本地验证原始证据；保留在磁盘，默认不进入源码版本控制。
- `poc/`：历史探针、靶标和实验，不随产品整理移动或覆盖。

项目已使用 Git，公开源码仓库为 [macOS-ClickThrough](https://github.com/realDGD/macOS-ClickThrough)。`.gitignore` 排除本地构建、原始实验日志及签名材料，`.editorconfig` 提供格式约定。

修改完成后运行 [相关检查](testing.md)，有长期取舍时更新 [Agent Note](../.agents/notes/README.md)。
