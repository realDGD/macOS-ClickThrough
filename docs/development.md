# 开发指南

## 环境

项目使用 Swift 6、AppKit、SwiftUI 和系统框架，没有第三方 Swift 包依赖。macOS 27 是主要开发和验证环境，当前工具链为 Xcode 27 / Swift 6.4；最低运行目标保持 macOS 14。开发主机、SDK／编译器和最低部署版本分别管理，最低运行版本不要求使用同年代的工具链。

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

## 目录

- `app/Sources/`、`app/Tests/`：产品与相关自动检查。
- `app/Resources/Info.plist`、`app/Package.swift`：应用与部署声明。
- `app/scripts/`：构建和打包入口。
- `app/build/`、`app/.build/`：可再生成的输出，不进入源码版本控制。
- `app/verification/`：本地验证原始证据；保留在磁盘，默认不进入源码版本控制。
- `poc/`：历史探针、靶标和实验，不随产品整理移动或覆盖。

当前目录尚未初始化 Git。`.gitignore` 和 `.editorconfig` 只提供整理约定，不会自动提交、清理文件或创建远程仓库。

修改完成后运行 [相关检查](testing.md)，有长期取舍时更新 [Agent Note](../.agents/notes/README.md)。
