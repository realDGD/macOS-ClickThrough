# Phase 3 本地版本验证

日期：2026-10-15。构建：ClickThrough 0.1.0 (1)，arm64，macOS 27，Swift 6。用户已批准实施计划及后续 Homebrew 安装方式。

后续最低版本已调整为 macOS 14，独立候选包为 0.1.0 (2)，见 [兼容调整验证](MACOS14_2026_10_15.md)。本文继续记录原构建的实际证据，不转记为新候选包或 macOS 14 实机结果。

## 已完成

| 项目 | 当前证据 |
| --- | --- |
| 设置与策略 | `swift test --package-path app`：10 项通过；规则、未知 ID、自身、两份列表持久化、手动／登录图标恢复、原修饰标志、AX 顺序与失败短路、取消开启意图 |
| 引擎迁移 | 同 session/head-insert tap；MainActor 同步；AXMain 成功才 AXFrontmost，保留 25 ms 对象超时和一次即时读回；普通事件返回同一个 CGEvent；up/drag 不激活 |
| 本地打包 | release 构建通过，无编译 warning/error；codesign --verify --strict 通过；LSUIElement=true，bundle ID local.clickthrough.app；Mach-O minos=27.0、sdk=27.0 |
| 依赖 | otool -L 仅系统框架／Swift 运行库，无遗漏的 SwiftPM 动态框架 |
| 设置 UI | 原生 AX 树与截图确认：功能状态、图标开关、登录项、规则选择与添加入口、诊断开关 |
| 隐藏后恢复 | 设置关闭显示图标 → Finder 双击同一个已运行的 ClickThrough.app → 显示图标开关恢复为 on；功能保持 stopped。直接经过真实 reopen 入口，没有修改偏好文件代替 UI |
| 权限失败控制 | 未授权时显示 permissionRequired，使用关闭图标；修正前没有取消入口。修正后“保持关闭”可回到 stopped，并清除 wantedEnabled |
| 独立审查 | 一位 fresh-context gpt-6-astra，只读审查。一个 Important 状态问题已修复，先观察 RED，再通过 10 项检查和上述 UI 场景。没有分派第二轮审查 |
| Homebrew 准备 | 生成 zip、SHA-256、release.json；解压后严格验签通过。隔离临时目录中以明确无效的测试 HTTPS 地址生成 Cask，Ruby Syntax OK，校验值对应该次 zip；测试目录自动清理，无 tap 注册／安装 |

后续无人值守检查发现：数字形式 `depends_on macos: ">= 27"` 虽通过 Ruby 语法，但无法通过当前 Homebrew 7 的 Cask DSL；已改为 `:golden_gate` 并确认实际解析为最低 27／arm64。也修复了本地重新打包后残留旧 Cask 的问题。回归见 `app/Tests/DistributionTests/test_package_release.py --homebrew`；没有安装软件或更换运行包。详细调研见 [后续方向](../research/UNATTENDED_API_DIRECTIONS.md)。

正式应用已完成 30 分钟空闲资源观察；诊断组件已完成 15 分钟持续负载、线程检查与压力验证，规则添加／切换／移除 UI 已检查并恢复原设置。完整统计和证据边界见 [无人值守结果](UNATTENDED_2026_10_15_RESULTS.md)。这不代替开启后的真实点击或登录重启验收。

实际产品路径：`app/build/ClickThrough.app`。

## 等待实际验收

- 用户已为正式应用授权，原构建和图标调整后的构建均已在原生设置界面确认“已开启”。图标调整使用 16 pt regular 的 SF Symbol 配置，两种状态均由默认 15×16 pt 放大为 19×20 pt；点击引擎源码未改。新 ad-hoc 构建曾在系统条目显示开启时仍不被信任，用户删除旧条目并重新添加当前路径后恢复；这不代替独立的撤权恢复验收。
- 原生菜单栏左右键分工已通过用户真实操作：左键关闭时靶标 4→4，重新开启后 4→5；右键可打开设置且不关闭功能，原生 AX 界面确认开启图标。产品日志有 stopped/started，与业务效果一致；没有额外枚举系统 tap 来声称独立的释放证明。
- 新产品二进制的首次后台原生单击、双击、拖出取消和恢复已通过本轮真实鼠标试次：计数依次为 0→1、1→3、3→3、3→4；后台右键菜单与菜单动作各 +1，均有独立靶标业务日志。详见 [本轮物理回归](PHASE_3_PHYSICAL_2026_10_15.md)。首次文本输入和浏览器真实复制尚未在本次产品二进制新增验收，历史 PoC 成功不直接转记为产品已通过。本轮结束已关闭诊断并退出测试靶标，功能保留开启。
- 当前本地登录项 status 为 notFound；没有注册登录项，也没有用固定路径假设代替实际注册和重启结果。登录启动标记使用 Apple 文档的 open-application event / keyAEPropData 解析，实际登录尚未验证。
- TCC 撤权、系统 tap 停用后 UI 时机、长时间性能和更广应用／多屏条件没有新增实测。没有更改 yabai、skhd、Karabiner 或 AutoRaise 配置。
- 当前是 ad-hoc 开发签名，未做 Developer ID、公证、Staple、公开 release 或 Homebrew tap 发布。Cask 工具和安装方法已具备，公开安装命令尚不可用。

## 原实验保存核对

迁移前后 SHA-256 一致：

| 文件 | SHA-256 |
| --- | --- |
| poc/activation-preserve/Probe.swift | f90b75ea006b52d7cce0aa76e41290b2dbfca418b2b8bef6790348786d4dc6e6 |
| poc/activation-preserve/ActivationPolicy.swift | 03672ec9853f165e7f8c84c043cf8872e9ff860efd0d1c59ccc27256e5d03e48 |
| FirstClickProbe.app/Contents/MacOS/FirstClickProbe | d789f955d174b669e99c0584abe4499156fb31f199c66ae5225c5b25e28d1577 |

原 A4 探针和 BackgroundButtonProbe 进程均未运行。不 raise 方向继续暂停，不进入新产品。
