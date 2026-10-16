# ClickThrough 应用

原生 macOS 菜单栏应用，最低部署目标 macOS 14，当前包为 arm64。A4 主路径使用窗口 AXMain → 应用 AXFrontmost，并保留同一个真实鼠标事件；目标窗口会正常激活并前移。

## 使用

首次启动处于关闭状态。左键菜单栏图标切换功能；右键显示设置和退出。为 ClickThrough 单独授予辅助功能权限后，再点击开启。原 PoC 的授权不能直接沿用。

- 关闭和运行图标分别使用 `cursorarrow.click`、`cursorarrow.click.2`。在新系统上，它们对应 `pointer.arrow.click` 系列；保持已调整的图标字号。
- 隐藏图标后继续运行。从 Spotlight 或 Finder 重新打开软件，恢复图标且保持功能开关。登录启动保留隐藏设置。
- 黑名单忽略所列应用，空列表处理所有符合条件的应用。白名单只处理所列应用，空列表全部跳过。两份列表独立保存，按 bundle ID 匹配。
- 登录项使用 SMAppService，只在用户切换时注册。系统要求批准时提供入口；移除软件前先关闭登录启动。
- 修饰点击保留系统行为；当前沿用 A4 对 Caps Lock、Fn 等标志的过滤。特殊窗口层、自身和命中失败的点击直接通过。
- 系统暂停监听后不循环重启；图标显示非运行状态，用户可手动重新开启。

菜单栏图标反映实际引擎状态，不根据“用户想开启”就显示已运行。AX 支持和目标应用事件处理可能限制首次点击效果；[测试说明](../docs/testing.md) 列出已有证据和未验收范围。

## 本地数据

bundle ID 为 `local.clickthrough.app`，设置保存在相应 UserDefaults。诊断默认关闭；开启后写入 `~/Library/Logs/ClickThrough/session-*.jsonl`，每进程上限 2 MiB，不记录键盘输入、剪贴板、网页正文或窗口标题。不会自动删除旧日志。

本地默认 ad-hoc 签名，更新构建可能需要用户重新添加辅助功能授权。不要同时运行开发副本和另一份已安装实例。

## 开发与安装入口

- [开发指南](../docs/development.md)：构建、候选包与运行方法。
- [分发与 Homebrew](../docs/distribution.md)：归档、签名、公证、Cask 和安装方法；公开 tap 尚未发布。
- [当前架构](../docs/architecture.md)：组件与 A4 固定约束。
- [macOS 14 版本调整验证](../docs/validation/MACOS14_2026_10_15.md)：本次候选包和证据边界。
