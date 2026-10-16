# ClickThrough Phase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** 将已验证的 A4 路径迁移为原生菜单栏软件，支持左右键分工、登录启动和应用规则。

**Architecture:** 单进程 AppKit 菜单栏入口 + SwiftUI 设置；引擎同步执行 A4，返回同一个真实事件。规则与生命周期状态可独立验证；登录项使用 SMAppService.mainApp。

**Tech Stack:** Swift 6、macOS 27、AppKit、SwiftUI、ApplicationServices、CoreGraphics、ServiceManagement、Swift Testing；无第三方依赖。

**Spec:** `docs/architecture/PHASE_2_A4.md`，补充本次用户明确指定的菜单栏、登录项与应用规则要求。

## 用户交互与默认值

- 左键菜单栏图标切换引擎。右键显示菜单：状态、设置…、退出。
- 实际运行用 `pointer.arrow.click.2`；停止、需要授权或系统暂停用 `pointer.arrow.click`。两个名称已在本机验证可用。
- 首次启动功能关闭，菜单栏图标显示。设置包含功能状态、权限入口、显示菜单栏图标、登录时启动、应用规则、可关闭诊断。
- 隐藏图标后应用和引擎继续运行。从 Spotlight／应用程序文件夹手动重新打开软件，自动恢复图标；不改变功能开关。登录自动启动保留隐藏设置。
- 黑名单模式：只忽略所列应用，默认空列表。白名单模式：只处理所列应用，空列表不处理任何应用。切换时保留两份列表。
- 用 bundle ID 匹配；通过系统应用选择框添加现有应用，去重，可移除。不依赖显示名、PID 或业务控件名称。自身始终跳过；无法确定 bundle ID 的目标在白名单下跳过。
- 登录项默认关闭；用户操作时注册／注销 SMAppService.mainApp，显示真实系统状态；需要批准时给出系统设置入口。
- 自动恢复的是用户期望开启状态；权限缺失、tap 创建失败或系统暂停时图标显示关闭状态，提供手动恢复，不循环弹授权提示。

## Global Constraints

- 最低目标 macOS 27，不增加旧系统分支。
- 保持 A4 的 session/head-insert 主动 tap、MainActor 同步处理、窗口 AXMain → 应用 AXFrontmost → 原事件通过。
- 保留每对象 25 ms AX 超时与一次 AXFrontmost 即时读回；不把返回成功视为业务成功。
- 保留现有修饰标志过滤、同应用后台窗口处理与 up/drag 原样通过。非普通窗口层、自身、命中不确定均放行。
- 不创建、修改、吞下、缓存或重放鼠标事件；失败无备用策略、无自动重试和 debounce。
- 不加入 AXPress、私有 API、SIP 修改、进程注入、AutoRaise、Focus Follows Mouse 或暂停的“不 raise”路线。
- 不修改原 PoC、已生成二进制及实验日志。不安装第三方软件，不扩大浏览器／应用测试范围。
- 产品代码放入独立 `app/`。当前目录没有 Git 仓库，使用目录隔离，不初始化 Git，不创建虚构提交。
- 构建固定 bundle ID 与固定本地路径；ad-hoc 开发签名可能需要重新授权。首次稳定构建后再申请产品自身 AX 权限。
- 日志不记录键盘、剪贴板、网页正文、窗口标题；默认关闭详细点击诊断。构建、UI 检查与物理点击业务验收分别记录。

## Review Focus

1. 手动重新打开与登录自动启动必须分开，隐藏后仍能找回图标。
2. 权限缺失／tap 停用时不得显示正在运行或残留有效拦截。
3. 同应用另一窗口不能因为 PID 已在前台而跳过 A4。
4. 白名单空列表／未知 bundle ID 必须确实跳过，切换模式不能丢列表。
5. 双击、拖出取消、修饰点击保持原始事件语义；不以 AX 成功代替业务结果。

## Task 1：设置与策略

**Files:** `app/Package.swift`、`app/Sources/ClickThroughCore/Settings.swift`、`InputPolicy.swift`、`RuntimeState.swift`；`app/Tests/ClickThroughCoreTests/PolicyTests.swift`。

**Interfaces:** `AppSettings` 可 Codable，保存规则模式、两份应用列表、图标显示与期望开关；`allows(bundleID:selfBundleID:) -> Bool`；`isUnmodifiedMouseClick(_:) -> Bool`；`RuntimeState` 提供实际运行状态和图标名。

- [x] 写规则测试：黑名单默认放行；白名单空／未知拒绝；自身拒绝；同名不同 ID 不混淆；切换与序列化保留两份列表。
- [x] 写恢复策略测试：手动重新打开恢复图标但不改功能；登录启动保留隐藏设置。
- [x] 执行 `swift test --package-path app`，确认因功能尚不存在而失败。
- [x] 实现策略、状态及设置存储；检查包含 Caps Lock/Fn 的现有过滤集合与非键盘 flags 的区别。
- [x] 同一命令通过，记录结果。

## Task 2：A4 引擎迁移

**Files:** `app/Sources/ClickThroughCore/ActivationSequence.swift`；`app/Sources/ClickThrough/WindowResolver.swift`、`A4Activation.swift`、`EventTapEngine.swift`、`Diagnostics.swift`；`app/Tests/ClickThroughCoreTests/ActivationTests.swift`。

**Interfaces:** `ActivationSequence.run(window:application:)` 严格窗口先行且窗口失败短路；`EventTapEngine.start() / stop()`、`state`、`settings`，状态变化回调供 UI 消费。

- [x] 写顺序与短路测试，先看到失败，再实现无备用／无重试的调用编排。
- [x] 从冻结 A4 迁移窗口命中、AXMain、AXFrontmost、同事件返回及超时策略；仅改善结构化错误表达。
- [x] 实现启停、创建失败、系统停用资源释放与手动恢复；tap disabled 不自动重建。
- [x] 执行核心测试并编译；对照冻结源检查没有前台 PID 快捷跳过、事件构造或重投路径。

## Task 3：菜单栏、设置、登录项

**Files:** `app/Sources/ClickThrough/AppDelegate.swift`、`AppModel.swift`、`StatusItemController.swift`、`SettingsView.swift`、`LoginItemController.swift`、`main.swift`；相关状态测试。

**Interfaces:** AppModel 连接持久设置、实际引擎状态与 UI；登录项状态来自 `SMAppService.mainApp.status`；启动／reopen 经过 Task 1 的显示恢复策略。

- [x] 先写实际状态映射与恢复测试，确认失败，再接通状态流。
- [x] 用 NSStatusItem.button 分派 leftMouseUp／rightMouseUp；左键切换，右键临时弹菜单。
- [x] SwiftUI 设置实现开关、隐藏图标、权限入口、登录项真实状态与应用列表选择／移除。
- [x] 实现手动冷启动及运行中 reopen 恢复图标；登录启动保留隐藏设置。
- [ ] 编译并用原生 UI 检查左右键分工、图标状态、设置、隐藏后重新打开；不借此注册登录项或更改第三方工具。

## Task 4：本地打包、审查与必要验收

**Files:** `app/scripts/build-app.sh`、`app/Resources/Info.plist`、`app/README.md`；更新根 README 与本计划进度记录。

**Interfaces:** 构建输出 `app/build/ClickThrough.app`；固定 bundle ID `local.clickthrough.app`、LSUIElement、最低系统 27。构建不安装到系统目录、不修改登录项。

用户追加：提供 Homebrew Cask 安装方式。生成 zip 与带真实 SHA-256 的 Cask；发布地址由发布步骤提供，不虚构已可用的公开安装命令。

- [x] 执行 `swift test --package-path app`、release 构建、codesign 严格验证、plist 与版本目标检查。
- [x] 由执行技能要求的一位独立审查者检查最终差异，重要问题只做一轮有针对性的修正，不扩大测试范围。
- [x] 核对冻结 PoC 源码与二进制哈希不变，确认没有并行活动的旧探针影响新引擎。
- [ ] 启动稳定产品包后申请产品自身 AX 权限；经用户物理输入做小范围 A4 迁移回归：后台按钮一次 +1、首次输入、拖出取消。原生 UI 自动化不代替关键输入。
- [x] 记录实际通过、尚需用户操作、尚未分发三类状态。登录重启、Developer ID 与公证没有实做就不声称完成。见 docs/validation/PHASE_3_LOCAL.md。

## 公开 API 依据

- [SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)
- [SMAppService.register()](https://developer.apple.com/documentation/servicemanagement/smappservice/register())
- [SMAppService.Status](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum)
- [NSApplicationDelegate reopen](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldhandlereopen(_:hasvisiblewindows:))
- [keyAELaunchedAsLogInItem](https://developer.apple.com/documentation/coreservices/keyaelaunchedasloginitem)
