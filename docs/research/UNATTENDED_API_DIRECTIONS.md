# Phase 3 后续方向：无人值守调研

日期：2026-10-15。用于收敛 A4 后续测量和优化，不重新选择架构，不恢复已暂停的“不 raise”方向。D 表示 Apple／Homebrew 文档明确说明，S 表示当前源码或本机 SDK 确认，E 表示本轮实验，H 表示仍需验证。

## 1. 用公开统计补充回调耗时

**D/S：** `CGGetEventTapList` 和 `CGEventTapInformation` 提供 tapping PID、enabled 及 min/avg/max 微秒延迟。可在人工业务试次中配合目标动作日志，判断耗时是否主要发生在 tap 回调。[接口](https://developer.apple.com/documentation/coregraphics/cggeteventtaplist(_:_:_:))、[结构](https://developer.apple.com/documentation/coregraphics/cgeventtapinformation)。

**S：** SDK `CGEvent.h` 明确说明，枚举会把返回列表中的 min/max latency 重置为相应平均值；它具有统计副作用。不能将它包装为无副作用的高频健康轮询，也不能只在读取完整列表后筛选自身 PID，便声称其他 tap 的统计完全未受影响。

**E：** 本轮做了一次计数＋列表读取，正式产品 PID 68186 没有匹配的 tap，符合尚未开启的观测条件。没有创建或启停 tap。发现统计副作用后不继续周期调用；30 分钟进程观察只用 ps/lsof。

**H／建议：** 下一轮人工验收开始前确定统一统计采集边界，读一次起点、一次终点，避免多个监视器互相重置窗口。API 只有 min/avg/max，不能生成真实 P95；也不能代表从硬件到按钮业务执行的完整延迟。

**D／另一种测量入口：** `OSSignposter` 可用同一线程中的同步闭包区间测量任务，也可借助 isEnabled 判断是否记录。以后若需要测分段耗时，可围绕完整回调、窗口步骤、应用步骤建立区间，在 Instruments 中看时间线；这不会调用 CGGetEventTapList 去重置其他 tap 的统计。仍需明确其范围是本进程执行区间，不是目标业务完成时间。[OSSignposter](https://developer.apple.com/documentation/os/ossignposter)。本轮仅调研，未加进当前运行包。

## 2. 修正 25 ms 超时的表述

**D：** 传入 system-wide AX 对象时，`AXUIElementSetMessagingTimeout` 改的是**本进程的全局 AX 超时**；传入其他 AX 对象时才仅覆盖该对象，且不自动作用于另一个相等的对象。[官方文档](https://developer.apple.com/documentation/applicationservices/1459345-axuielementsetmessagingtimeout)。

**S：** A4 首先对 system-wide 对象设 0.025 s，再对命中的窗口和应用对象显式设相同值。现有源码没有改变。这比“每对象 25 ms”更完整：既有本进程全局默认值，也有特定对象的覆盖。两者都不构成整段回调的硬截止时间。

**H／建议：** 若实际回调出现长尾，先分别测窗口命中、AXMain、AXFrontmost 以及读回，区分失败路径；不通过追加重试、延时补点或另起线程掩盖。

## 3. AX 通知适合诊断，不能当同步激活屏障

**D：** AXObserver 绑定具体应用，系统级 AX 对象不支持该通知注册；观察多个应用需要多个 observer。通知名称可描述应用激活、焦点等变化。[注册接口](https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification)、[通知机制](https://developer.apple.com/documentation/applicationservices/axnotificationconstants_h)、[应用激活通知](https://developer.apple.com/documentation/applicationservices/kaxapplicationactivatednotification)。

**H／建议：** 若出现“AX setter 成功但业务没有执行”的明确故障，可以在独立诊断器中关联这些通知、原始事件号和目标动作日志。不能由通知存在推出它必定先于当前点击处理，也不建议现在引入全应用 observer 管理和激活缓存。

## 4. 性能优化优先级

| 候选 | 已知依据 | 当前决定 |
| --- | --- | --- |
| 只订阅左右 down，不订阅 up/drag | D：tap mask 决定接收哪些事件；S：当前 up/drag 只进入回调后放行 | 保留为低侵入优化候选；先完成人工迁移回归，再比较真实拖动时的 CPU 与语义，不随本次测试改运行包 |
| 修改键／规则提前过滤 | S：已经在 AX 激活前过滤 | 保持；本轮压力验证通过 |
| 列表改 Set／缓存 owner 身份 | E：1000 条黑名单 miss 平均约 2.2 µs；10000 条约 24.4 µs | 当前没有这部分构成瓶颈的证据；避免提前引入 PID 复用和失效缓存问题 |
| 主路径移到工作线程或异步激活 | S：会改变 A4 的 AppKit 隔离和事件时序 | 无性能证据前不采用 |
| 删除即时读回或调整 AX 超时 | S：会改变冻结基线调用顺序 | 只在独立受控试验中比较，不与产品迁移合并 |

mask 依据：[CGEventMask](https://developer.apple.com/documentation/coregraphics/cgeventmask)。系统可因不响应而停用 tap：[tapEnable](https://developer.apple.com/documentation/coregraphics/cgevent/tapenable(tap:enable:))。这些文档没有给出可作为产品承诺的固定 watchdog 毫秒值。

**E：** 在独立、未授权的测试进程中，`AXIsProcessTrusted()` 首次调用约 36.9 ms，后续 1000 次 P50 约 0.459 µs、P99 约 0.625 µs。正式引擎在 start 前检查信任，本轮没有观察到 warm 检查成为瓶颈。这不是正式应用身份或 AX 激活耗时的测量，也不是稳定性能保证。

**S／后续通用策略问题：** 原 A4 过滤集合包括 Caps Lock 状态。当前 Caps Lock 打开时，即使未按 Cmd／Option 等组合键，也会跳过增强处理。这是已批准迁移约束保留的行为，本轮没有改动。未来应单独比较“状态标志”和“保留给窗口管理器的修饰点击”：先用同一个原生靶标各做一次 Caps Lock 开／关试次，再决定是否从过滤集合排除 maskAlphaShift。Fn、Ctrl、Option 等仍需保留工具共存语义，不根据某个应用名称放行。[Caps Lock 标志](https://developer.apple.com/documentation/coregraphics/cgeventflags/maskalphashift)、[NonCoalesced 标志](https://developer.apple.com/documentation/coregraphics/cgeventflags/masknoncoalesced)。

## 5. 登录启动与手动恢复

**D：** Apple 明确用 open-application Apple Event 中 keyAEPropData 的值区分 login/service launch；正式实现采用该机制。[Launch Apple Event Constants](https://developer.apple.com/documentation/coreservices/1556410-launch_apple_event_constants)。手动 reopen 仍恢复图标，不改开启意图。

**D：** SMAppService.mainApp 可直接从主应用注册登录启动，不需要辅助 app 或 daemon；注册结果受用户批准影响，mainApp 对应后续登录启动。[mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)、[register](https://developer.apple.com/documentation/servicemanagement/smappservice/register())、[Apple DTS 示例](https://developer.apple.com/forums/thread/777520)。

**E／限制：** 当前 UI 曾返回 notFound，原因未定位。不能由它保证“移动到 Applications 一定解决”；没有用户可用的登录／重启环境，本轮不注册、注销或重启来制造验收结论。后续在最终固定安装位置做一次用户主动开启和一次登录实测即可，不扩大到所有启动方式。

## 6. 分发与签名

**E：** 当前 ad-hoc 包的 designated requirement 是 `cdhash H"6017bb4768c691168413835c09b957e91d5d8195"`。它并非仅凭 bundle ID 建立稳定签名要求，因此本轮保留当前运行包不重建。Developer ID／公证、升级后的授权继承仍需正式分发时验证，不承诺仅同名同路径即可免重新授权。

**D/S/E：** Homebrew 当前要求 macos 最低版本使用版本符号；本机及官方 MacOSVersion 映射 `golden_gate` 为 `27`。原数字比较写法 Ruby 语法合法，却被实际 Cask DSL 拒绝。已改为 `depends_on macos: :golden_gate`，真实 DSL 回归得到 minimum=27、comparator=>=、arm64 与匹配 SHA-256。[Cask Cookbook](https://docs.brew.sh/Cask-Cookbook#depends_on-macos)、[版本映射](https://docs.brew.sh/rubydoc/MacOSVersion.html)。

安装仍需真实 HTTPS 发布地址和 tap。临时文本解析没有安装软件、注册 tap 或发布地址。测试使用 Homebrew 内部 loader 仅用于当前开发验证；生成的 Cask 本身只使用文档化 DSL，不将内部 Ruby API 作为产品或用户安装入口。

正式分发顺序应是 Developer ID 签名／Hardened Runtime → 用 notarytool 提交并检查结果 → 对 app staple → **重新生成**最终 ZIP 和 SHA-256／Cask。ZIP 可以提交公证，却不能直接 staple；票据附到 app 后必须重新压包。因此不能在 staple 之前固定最终 Homebrew 校验值。[Apple 公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)。本轮没有读取证书、使用凭据或提交公证。

## 7. macOS 27 控件事件的新入口

**D/S：** NSControl.Events 在本机 SDK 27 中有 trackingRepeated、valueChanged、primaryActionTriggered 和 menuActionTriggered 等事件。它们作用于本进程控件，可作为未来菜单栏自身交互整理的研究入口；并不改变其他应用对首次点击的决定。[menuActionTriggered](https://developer.apple.com/documentation/AppKit/NSControl/Events/menuActionTriggered)。

**H／决定：** 没有证据表明 NSStatusBarButton 的 menuActionTriggered 等同于所要求的右键 mouse-up，也没有验证它能替代当前左右键分工。因此本次保持既有按钮 target/action；不因出现新名字而改已选路径。需要整理时先对独立本机控件做语义试验，再考虑产品迁移。
