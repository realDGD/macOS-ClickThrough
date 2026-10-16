# macOS Universal First-Click：Phase 0 技术调研报告

调研日期：2026-10-14（用户所在时区 UTC+8）。目标系统：macOS 27。状态：文档、官方示例与源码调研完成；**尚未进行鼠标事件或目标应用的运行时实验，最终架构未确定。**

## 1. 调研结论与证据边界

**公开 API 提供了应用内首次点击策略、全局事件过滤、跨进程 AX 命中与动作、事件重新投递等能力。本轮未发现由第三方进程全局强制所有控件接受首次点击的公开开关，也未找到保证跨进程激活先于当前鼠标事件处理完成的公开事务接口。** 这不足以证明所有通用方案都不可行，但不足以承诺任意应用、任意控件的百分之百覆盖。[NSView 官方文档](https://developer.apple.com/documentation/appkit/nsview/acceptsfirstmouse(for:))、[Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz-event-services)、[协作激活说明](https://developer.apple.com/documentation/appkit/passing-control-from-one-app-to-another-with-cooperative-activation)。

建议先验证“点击发生时，通过公开 API 提前激活准确的目标窗口，保留并放行真实事件”的路线 A。它符合 Native Behavior First，但目前只是**优先实验对象**。同时独立验证 AX 语义动作 B、激活后重新投递 C、无需先激活的 PID 定向投递 D；不得在未实测前把 A 或 C 写成正式架构。

发现了两个值得修正既有经验的事实：

- SwiftUI 已有 `allowsWindowActivationEvents`，可以配置自身视图的激活点击处理；它不是修改其他应用视图的跨进程接口。[官方说明](https://developer.apple.com/documentation/swiftui/view/allowswindowactivationevents(_:))。
- Chromium 当前开发分支在 `acceptsFirstMouse:` 中专门接受特定跨进程投递的点击。本机 Chrome 155 对应标签源码尚无这段逻辑，因此不能把开发分支行为当作已安装浏览器的行为。详见第 4.4 节。

证据标签：

| 标签 | 含义 | 能证明什么 |
| --- | --- | --- |
| **D** | Apple 当前官方 API 文档或 SDK 的明确约定 | 接口能力和约定；不自动证明组合方案有效 |
| **DTS** | Apple 开发者技术支持的公开解释 | 权限与平台边界的官方解释；与 API 契约分开记录 |
| **S** | 固定版本的开源源码 | 该版本如何实现；不等于本机验收结果 |
| **L** | 本机只读检查 | 系统、SDK、应用标识或进程存在状态 |
| **H** | 未验证的技术假设 | 必须由 Phase 1 证明或推翻 |
| **I** | 基于上述证据的分析、风险和建议 | 推论或实验优先级，不冒充文档保证 |

### 1.1 本机环境与当前覆盖空缺

**L**：`sw_vers` 报告 macOS **27.0.1 / 26A434**；`xcodebuild -version` 报告 **Xcode 27.0 / 27A266a**；SDK 标识为 **macosx27.0**；CPU 架构为 arm64。研究开始时项目目录为空，且不是 Git 仓库，没有可继承的既有实现。

**L**：Chrome 为 **155.0.8059.79**，Safari 为 **27.0.1 / 22625.1.29.11.28**。常见安装目录未找到 Firefox；Spotlight 查询 `com.openai.chat` 没有返回结果。`/Applications/ChatGPT.app` 的实际 bundle identifier 为 **`com.openai.codex`**，版本 **26.1007.71326**，因此目标 ChatGPT 桌面应用身份尚待核实，不能仅按文件名认定。

**L**：检查时 yabai 和 skhd 进程正在运行；未检出名为 `karabiner_grabber` 的进程。这只证明进程名检查结果，不证明具体配置、权限、版本或兼容性。没有启动、停止或修改这些工具。

本机 SDK 的文件、哈希和相关行位置见 [SDK 审查记录](SDK_API_AUDIT.md)。网页的“最近抓取”日期不视为 API 新增日期；开发分支也不视为已发布版本。

## 2. Apple 当前公开能力清单

表中的 API 均属于研究对象，而非已选型的组件。仍受当前系统支持的早期公开接口可以使用；这与为旧系统编写兼容代码是两回事。正式最低部署目标固定为 macOS 27。

### 2.1 AppKit 与 SwiftUI

| API / 机制 | 当前公开能力 | 关键边界与本项目用途 | 官方链接 |
| --- | --- | --- | --- |
| `NSView.acceptsFirstMouse(for:)` | D：命中视图决定是否接受非活动窗口的初始 mouse-down；默认实现返回 false，部分控件接受 | 应用自身子类可以改变策略；第三方工具无法通过此接口给别的进程所有视图改策略 | [文档](https://developer.apple.com/documentation/appkit/nsview/acceptsfirstmouse(for:)) |
| SwiftUI `allowsWindowActivationEvents(_:)` / 无参数形式 | D：配置该视图层级的手势是否处理激活窗口的事件，受祖先层级和控件本身策略限制 | 直接、无需事件重放的应用内能力；不提供远程修改能力；用于 PoC 的正负对照 | [带参数](https://developer.apple.com/documentation/swiftui/view/allowswindowactivationevents(_:))、[无参数](https://developer.apple.com/documentation/swiftui/view/allowswindowactivationevents()) |
| `NSView.shouldDelayWindowOrdering(for:)` | D：允许拖动时延迟窗口排序及应用激活，通常延迟到 mouse-up | 解释后台拖动与窗口排序的特殊语义；不可把所有后台 down 强行激活而不验证拖动 | [文档](https://developer.apple.com/documentation/appkit/nsview/shoulddelaywindowordering(for:)) |
| `NSEvent.addGlobalMonitorForEvents` | D：异步取得发给其他应用的事件副本，不能修改或阻止原事件 | 适合观察和诊断；不提供保证抢在原事件之前完成激活的机制 | [文档](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)) |
| `NSEvent.addLocalMonitorForEvents` | D：可修改、删除本应用即将分派的事件 | 作用范围限本进程；不能解决全局第三方窗口问题 | [文档](https://developer.apple.com/documentation/appkit/nsevent/addlocalmonitorforevents(matching:handler:)) |
| `NSRunningApplication.activate(options:)`、`activate(from:options:)` | D：向系统请求应用激活；协作版本可表达让出激活的来源应用 | 应用激活不等于指定窗口成为 key，也不等于点击已经执行；回调与目标应用间的先后次序需测试 | [普通请求](https://developer.apple.com/documentation/appkit/nsrunningapplication/activate(options:))、[协作请求](https://developer.apple.com/documentation/appkit/nsrunningapplication/activate(from:options:)) |
| `NSApplication.yieldActivation(to:)` | D：当前活动应用可以让出激活给指定应用 | 后台菜单栏工具不能代替任意前台应用让出控制；不要求目标应用协作就不能假定该路径成立 | [文档](https://developer.apple.com/documentation/appkit/nsapplication/yieldactivation(to:)) |
| `NSWindow.windowNumber(at:belowWindowWithWindowNumber:)` | D：返回指定屏幕坐标下会被 mouse-down 命中的最前窗口编号 | 比遍历矩形更接近命中语义；坐标转换、透明区域、特殊窗口和与 AX 元素的关联仍需验证 | [文档](https://developer.apple.com/documentation/appkit/nswindow/windownumber(at:belowwindowwithwindownumber:)) |
| `NSApplication.sendEvent` / `postEvent`、`NSView.hitTest` | D：本应用的事件分派、排队和视图命中 | 不能获取别的进程的 NSWindow/NSView 对象来直接调用 | [NSApplication](https://developer.apple.com/documentation/appkit/nsapplication)、[NSView](https://developer.apple.com/documentation/appkit/nsview) |

**D / L**：SDK 27 把 `activateIgnoringOtherApps` 标为已弃用，注释明确说明该选项不再产生作用。禁止将它视为强制抢占焦点的现代能力，也不为它编写旧系统回退。[激活选项](https://developer.apple.com/documentation/appkit/nsapplication/activationoptions)、[协作激活](https://developer.apple.com/documentation/appkit/passing-control-from-one-app-to-another-with-cooperative-activation)。

### 2.2 CoreGraphics / Quartz

| API / 机制 | 当前公开能力 | 边界与研究用途 | 官方链接 |
| --- | --- | --- | --- |
| `CGEventTapCreate` / Swift `CGEvent.tapCreate` | D：在指定位置建立被动监听或主动过滤；主动回调可以放行、修改、替换或删除事件 | 监听和过滤能力明确；并不替目标应用决定是否接受 first mouse | [创建](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))、[回调契约](https://developer.apple.com/documentation/coregraphics/cgeventtapcallback) |
| HID / Session / Annotated Session tap | D：分别位于进入 WindowServer、进入登录会话、标注应用路由之后的事件阶段 | 路由标注可用时间、窗口命中字段与激活时序可能不同；应比较 Session 与 Annotated，而非先认定越底层越好 | [位置定义](https://developer.apple.com/documentation/coregraphics/cgeventtaplocation) |
| `CGEventTapCreateForPid` | D / L：按 PID 观察或过滤到指定进程的事件 | 已经选择目标进程，不是全局自动命中；没有 documented first-mouse bypass | [文档](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreateforpid(pid:place:options:eventsofinterest:callback:userinfo:)) |
| `CGEventTapPostEvent` | D：在 tap 所在阶段插入事件，下游 taps 可以看到；在同一回调中先于回调返回的事件进入系统 | 适合研究转发链及顺序；仍是重新投递，不能称为原始事件原封不动地自然通过 | [文档](https://developer.apple.com/documentation/coregraphics/cgevent/tappostevent(_:)) |
| `CGEventPost` | D：从指定流阶段投递，经过该位置上的 taps | 广播式路径可能再次被自己、窗口管理器捕获；需要防递归和配对验证 | [文档](https://developer.apple.com/documentation/coregraphics/cgevent/post(tap:)) |
| `CGEventPostToPid` | D / L：把事件投给指定进程，经过该进程的 taps；替代已弃用的 PSN 投递形式 | PID 不是 window ID；接口返回 void，没有动作完成回执，也没有统一绕过首次点击策略的保证 | [文档](https://developer.apple.com/documentation/coregraphics/cgevent/posttopid(_:)) |
| `CGEvent.copy`、类型、时间戳、位置、flags、字段读写 | D：读取或保留事件元数据 | 拷贝后重投仍属事件重新投递；保留字段不能独立保证保留系统对真实输入的全部语义 | [Quartz 总览](https://developer.apple.com/documentation/coregraphics/quartz-event-services) |
| `CGEventSource` 的 local events filter / suppression interval | D / L：配置投递后及合成拖动期间本地硬件事件的过滤 | SDK 声明默认不抑制本地键鼠，并列出默认 suppression interval 为 0.25 秒；二者要一起理解，不能误读为每次投递必然延迟或屏蔽 250 ms | [事件源总览](https://developer.apple.com/documentation/coregraphics/quartz-event-services)、[interval](https://developer.apple.com/documentation/coregraphics/cgeventsource/localeventssuppressioninterval) |
| `CGEventField` 的 click state、event number、source PID、target PID、user data、窗口命中字段 | D / L：公开字段访问；down/up 的 event number 和 click state 有说明 | `.mouseEventWindowUnderMousePointer` 与 `...ThatCanHandleThisEvent` 已公开；公开可写字段不等于文档保证修改它就能重新路由或强制控件接受事件 | [字段定义](https://developer.apple.com/documentation/coregraphics/cgeventfield) |
| `CGEventTapEnable`、`CGEventTapIsEnabled`、`CGGetEventTapList` | D：检查、恢复 tap，并获取 tap 信息和延迟数据 | watchdog 禁用与错误恢复要纳入验证；统计读取会重置部分延迟极值，测量需记录这一行为 | [Quartz 总览](https://developer.apple.com/documentation/coregraphics/quartz-event-services) |
| `CGPreflightListenEventAccess` / `CGRequestListenEventAccess` | D / L：检查和请求监听能力 | 不在调研阶段触发授权；测试时分清监听权限与 AX 权限 | [检查](https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess())、[请求](https://developer.apple.com/documentation/coregraphics/cgrequestlisteneventaccess()) |
| `CGPreflightPostEventAccess` / `CGRequestPostEventAccess` | D / L：检查和请求合成、投递能力 | 检查结果与真实 tap/投递是否可用应分别记录 | [检查](https://developer.apple.com/documentation/coregraphics/cgpreflightposteventaccess())、[请求](https://developer.apple.com/documentation/coregraphics/cgrequestposteventaccess()) |
| `CGWindowListCopyWindowInfo` | D：窗口列表、边界、层级、owner PID 等元数据 | 矩形包含不是完整命中测试；不得把窗口名称是否缺失当作权限检测 | [文档](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:)) |

**D 与 S 的未解决差异**：当前 `CGEventTapCreate` 文档及 SDK 注释仍称 HID 位置要求 root；yabai 源码却使用 HID tap。这不能证明 macOS 27 的任意普通进程可以建立该 tap。本项目不把 root、关闭 SIP 或未经验证的权限例外列为默认前提；若实验调查该差异，必须记录实际 UID、TCC 状态和创建结果。[官方创建说明](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))、[yabai 源码](https://github.com/asmvik/yabai/blob/dd845723416f5fe92af49fad5ebab00369e07edd/src/mouse_handler.c#L273)。

### 2.3 Accessibility

Apple 部分 AX 符号页面的 Markdown 端点返回 404；本轮改为读取 Apple 提供的 **DocC JSON**，并与 SDK 27 头文件交叉核对。没有把抓取失败解释为 API 不存在。来源索引保留了实际获取方式。

| API / 机制 | 当前公开能力 | 边界与研究用途 | 官方链接 |
| --- | --- | --- | --- |
| `AXUIElementCreateSystemWide` / `CreateApplication` | D：系统范围或按 PID 建立可访问性对象 | AX 是跨进程消息协议，不是远程 NSView 指针 | [AX API 索引](https://developer.apple.com/documentation/applicationservices/axuielement_h) |
| `AXUIElementCopyElementAtPosition` | D：按屏幕左上原点坐标及窗口 z-order 命中顶层可见元素 | 可以识别按钮、链接、输入框、菜单、所属窗口与 PID；返回内容受目标应用可访问性实现影响 | [文档](https://developer.apple.com/documentation/applicationservices/1462077-axuielementcopyelementatposition) |
| `AXUIElementGetPid`；`kAXWindowAttribute`；role/subrole/parent | D / L：获得元素所属进程与窗口层级 | `kAXWindowAttribute` 是公开的窗口关联入口，可避免先采用私有 `_AXUIElementGetWindow` | [API 索引](https://developer.apple.com/documentation/applicationservices/axuielement_h)、[属性](https://developer.apple.com/documentation/applicationservices/carbon_accessibility/attributes) |
| `AXUIElementCopyActionNames` | D：枚举目标实际支持的动作，可以为空 | 必须按能力判断，不能凭 role 等于 button 就假定 AXPress 有效 | [文档](https://developer.apple.com/documentation/applicationservices/1462053-axuielementcopyactionnames) |
| `AXUIElementPerformAction`；`kAXPressAction`；`kAXShowMenuAction` | D：请求单击语义动作或显示关联菜单，无需构造鼠标 down/up | 这是语义动作，不是任意鼠标事件；无位置、click count、修饰键或拖动序列参数；右键菜单能力依目标而异 | [执行](https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction)、[动作说明](https://developer.apple.com/documentation/applicationservices/carbon_accessibility/actions) |
| `AXUIElementIsAttributeSettable` / `SetAttributeValue` | D：查询并设置可写属性 | 可以研究窗口 main/focused、应用 frontmost；`AXMain` 不保证 key focus，控件 `AXFocused` 不等于执行控件操作 | [查询](https://developer.apple.com/documentation/applicationservices/1459972-axuielementisattributesettable)、[设置](https://developer.apple.com/documentation/applicationservices/1460434-axuielementsetattributevalue) |
| `AXRaise` | D：在应用允许的条件下提升窗口 | raise、应用 active、窗口 key 和按钮动作是不同状态；不能把 raise 成功当作任务完成 | [动作说明](https://developer.apple.com/documentation/applicationservices/carbon_accessibility/actions) |
| `AXObserver`；focus/window 通知 | D：观察目标提供的状态变化 | 可作实验观测，通知支持与到达时机并非所有目标一致；不能预设为鼠标流排序屏障 | [创建](https://developer.apple.com/documentation/applicationservices/1460133-axobservercreate) |
| `AXUIElementSetMessagingTimeout` | D：限制 AX 消息等待时长 | AX 可能阻塞或超时；尤其不能把长 AX 调用无限放在 tap 回调里 | [文档](https://developer.apple.com/documentation/applicationservices/1459345-axuielementsetmessagingtimeout) |
| `AXIsProcessTrustedWithOptions` | D：检查 AX 客户端信任，并可提示用户；提示异步且不改变当次返回值 | 授权提示出现不等于授权已经生效 | [文档](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions) |

**D**：`AXUIElementPerformAction` 返回 `cannotComplete` 时，动作可能已经执行，只是目标的模态处理未及时返回。因此不能“AX 超时就立即补一个鼠标点击”，否则有重复执行风险。[官方错误语义](https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction)。

### 2.4 是否有更新、更底层的公开方案

- **D / L**：AppKit 2026 更新和 SDK 27 提供 `NSControl.Events`、基于 gesture recognizer 的拖动入口、手势排他行为、触控输入配置；这些作用于应用自身输入处理。没有从这些接口发现全局远程 first-click 策略。[AppKit 最新更新](https://developer.apple.com/documentation/updates/appkit)、[TN3212](https://developer.apple.com/documentation/technotes/tn3212-adopting-gesture-recognizers-for-sidecar-touch-support)。
- **D / I**：IOKit 的 IOHIDManager 可研究设备输入，`IOHIDRequestAccess` 处理输入访问权限；它们没有公开的跨进程窗口控件 first-mouse 策略。把监听位置下移到 HID 不会自动绕过 AppKit/浏览器内部的接收决定。[IOHIDManager API 集合](https://developer.apple.com/documentation/iokit/iohidmanager_h)、[IOHIDRequestAccess](https://developer.apple.com/documentation/iokit/3181574-iohidrequestaccess)。
- **DTS / I**：ScreenCaptureKit 的 `SCShareableContent` 是现代窗口枚举能力，但不是点击投递或控件动作 API。无需为了鼠标交互先引入屏幕捕获和额外权限；是否使用其枚举能力由 PoC 证据决定。[官方枚举接口](https://developer.apple.com/documentation/screencapturekit/scshareablecontent)、[Apple 对窗口元数据权限的解释](https://developer.apple.com/forums/thread/839069)。
- **I**：虚拟 HID、驱动扩展和全局设备重映射增加部署与设备层干预，仍不能证明目标应用会接受首次点击。它们不是当前约束下的优先候选。
- **S / I**：SkyLight/CGS/SLPS 私有窗口操作、私有事件记录、进程注入、swizzling 他人视图、修改他人 Electron 配置等可作为机制研究资料；不进入正式方案。

检索范围覆盖相关官方 API 集合、2026 AppKit 更新、macOS 27 输入技术说明及本机 SDK 核心头文件。**“本轮未发现”是有范围的研究结论，不宣称已经枚举整个 macOS 的每个公开符号。**

## 3. 后台首次点击的处理机制与官方示例

### 3.1 事件流和策略所在层

**D**：硬件/设备输入进入系统事件流，WindowServer 做窗口相关路由，应用的 `NSApplication` 把输入交给对应 `NSWindow`，窗口再做视图命中和 responder/gesture 处理。传统 AppKit 的非 key 窗口初始 mouse-down 默认用于激活；命中视图可通过 `acceptsFirstMouse` 接受这一事件，部分原生控件原本就允许。因而不能把所有后台首次点击都描述成在全局鼠标流中被统一丢弃。[事件分派说明](https://developer.apple.com/documentation/appkit/nsapplication)、[first-mouse 当前参考](https://developer.apple.com/documentation/appkit/nsview/acceptsfirstmouse(for:))、[Cocoa Mouse Events 历史指南](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingMouseEvents/HandlingMouseEvents.html)。

**D / S**：有三个独立状态需要区分：应用 active、窗口 key/main、控件 first responder。浏览器内容还能在其自身视图与网页进程中决定是否接收输入。单独观察应用变前台，不能证明 first mouse 被送到业务处理器。

**D / I**：完整点击可能在 mouse-up 才执行，并允许按下后移出按钮取消；拖动需要 down、drag、up 连贯序列；双击依赖 click count 和时间；修饰键属于操作语义。强制激活或立即 AXPress 都可能改变这些行为。右键可能本来就能弹出后台上下文菜单，必须单独测基线，不能从左键推导。

**D**：macOS 27 的 AppKit 正在加强 gesture recognizer 模型，TN3212 描述了对命中层级与 Sidecar 输入的处理。历史 mouseDown 示例帮助解释机制，不能作为新系统所有手势行为的完整契约。[TN3212](https://developer.apple.com/documentation/technotes/tn3212-adopting-gesture-recognizers-for-sidecar-touch-support)。

### 3.2 官方示例实际提供的证据

| 官方材料 | 观察到的能力 | 年代与边界 |
| --- | --- | --- |
| SwiftUI `allowsWindowActivationEvents` 的 Rectangle / HStack 示例 | 配置自身层级；外层设置可覆盖内层 | 当前参考；不处理外部进程 |
| AppKit 协作激活的 TextEdit 示例 | 当前活动应用 yield，然后请求目标 activate | 当前参考；没有“后台守护工具替任意前台应用 yield”的示例 |
| Cocoa Event Handling Guide 的 Sketch mouseDown 示例 | click count、命中、选区与拖动跟踪等应用内语义 | 历史官方示例；不作为 macOS 27 全局工具实现模板 |
| AnimatedTableView 的事件监视示例 | 本应用弹窗关闭与本地过滤，说明 global/local 的边界 | [历史官方材料](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html)，2016 更新 |
| UIElementInspector | 命中其他应用 AX 元素，读取属性，枚举并触发其提供的动作 | [官方示例](https://developer.apple.com/library/archive/samplecode/UIElementInspector/Introduction/Intro.html)，2010 版本；仅用来佐证 AX 客户端工作方式 |
| TN3212 的 gesture recognizer 示例 | macOS 27 下自身视图的输入、拖动和手势迁移 | 当前系统资料；没有提供第三方全局强制 first mouse 能力 |

本轮未找到 Apple 维护的“第三方进程全局改写所有应用首次点击策略”的现成示例；这条负面检索结果不等于系统不可能存在可用组合方案。

## 4. 开源实现审查

只读取源码和文档，没有安装、运行或复用这些项目代码。引用固定 revision；作者声明和用户 issue 均不视为本机验证。

### 4.1 Hammerspoon 与 apple-click-through

**S**：`apple-click-through` 审查 revision 为 `ee0be75cd007c391789a7be86e83076c4d3ba2e5`。`event.lua` 仅监听 `leftMouseDown`；优先通过 AX 命中，再在失败时寻找包含鼠标坐标的窗口。它调用窗口 `focus()` 或设置元素 `AXFocused`，最后返回 false，让原始点击继续。没有 AXPress 或鼠标重放主路径。[事件处理源码](https://github.com/dainank/apple-click-through/blob/ee0be75cd007c391789a7be86e83076c4d3ba2e5/clickthrough/event.lua#L36)、[监听掩码](https://github.com/dainank/apple-click-through/blob/ee0be75cd007c391789a7be86e83076c4d3ba2e5/clickthrough/event.lua#L157)、[目标选择](https://github.com/dainank/apple-click-through/blob/ee0be75cd007c391789a7be86e83076c4d3ba2e5/clickthrough/target.lua#L5)。

**S**：实现包含 50 ms 节流、全屏跳过、菜单/对话框跳过、光标种类跳过、特定窗口标题跳过，以及按几何匹配 AX 窗口。它提供了路线 A 的经验线索，但没有覆盖右键状态机或验证控件确实执行。其聚焦日志不能证明复制成功；README 的有效性声明没有提供足以复现全部要求的测试记录。[实现限制](https://github.com/dainank/apple-click-through/blob/ee0be75cd007c391789a7be86e83076c4d3ba2e5/clickthrough/event.lua#L13)、[几何关联](https://github.com/dainank/apple-click-through/blob/ee0be75cd007c391789a7be86e83076c4d3ba2e5/clickthrough/ax_utils.lua#L25)。

**S**：Hammerspoon 审查 revision 为 `23e387e2805a9890066366e0ac96c71b27f0cfd5`。`hs.eventtap` 使用 Session、head insert、主动过滤，Lua 返回 false 对应放行原事件；窗口 `focus()` 先设 main，再调用应用 bring-to-front。[tap 创建](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/eventtap/libeventtap.m#L217)、[focus 路径](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/window/window.lua#L513)。

**S / I**：底层 bring-to-front 使用已弃用的 `SetFrontProcessWithOptions`，窗口编号关联使用私有 `_AXUIElementGetWindow`。因此不能说这份脚本已经证明“只用现代公开 API、macOS 27 全局稳定一次点击”。它也不能作为本项目直接复制的核心。[底层应用激活](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/Hammerspoon/HSuicore.m#L257)、[窗口关联](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/Hammerspoon/HSuicore.m#L657)。

历史 issue 报告过顶部菜单点击切回 Finder，以及上下文菜单/对话框干扰。它们说明保护真实 UI 路由的重要性，**不代表当前 revision 在 macOS 27 已复现这些 bug**。[项目 issue #12](https://github.com/dainank/apple-click-through/issues/12)、[早期 Gist 讨论](https://gist.github.com/dainank/fd236aa71a8b3fcf637b9d8428ce98db)。

### 4.2 yabai 与 skhd

**S**：yabai 审查 revision 为 `dd845723416f5fe92af49fad5ebab00369e07edd`。它的鼠标 tap 涵盖左右 down/up、drag、move；符合配置的鼠标修饰键可吞掉 down，在不发生拖动时于 up 阶段重新投递 down/up。此行为是窗口管理交互，不是通用后台控件 first-click 功能。[鼠标消费和转发](https://github.com/asmvik/yabai/blob/dd845723416f5fe92af49fad5ebab00369e07edd/src/mouse_handler.c#L31)。

**S**：其窗口 focus 使用 `_SLPSSetFrontProcessWithOptions`、`SLPSPostEventRecordTo` 的私有事件记录，并可调用 AXRaise；部分路径还包含时序延迟。这说明“窗口管理器能聚焦”不等于“公开 API 能无侵入地完成首次业务点击”。本项目不复用该私有实现。[聚焦代码](https://github.com/asmvik/yabai/blob/dd845723416f5fe92af49fad5ebab00369e07edd/src/window_manager.c#L1266)。

**S / I**：skhd 审查 revision 为 `a7105d5b3db6b25d01c0ded79a25536ab284b34f`，使用 Session head-insert tap。多个工具的 tap 可能处于不同阶段和插入顺序；“head insert”并不表示本工具永久拥有所有输入的第一处理权。必须在不同启动顺序和真实配置下验证，尤其保留 yabai 的 move/resize 修饰键操作。[skhd tap](https://github.com/asmvik/skhd/blob/a7105d5b3db6b25d01c0ded79a25536ab284b34f/src/event_tap.c#L9)。

### 4.3 AutoRaise、cliclick 与更简单的方案

**S**：AutoRaise revision `cfed9445695d8092a283fa54d9453072978c7262` 的目标是悬停聚焦/提升窗口；源码包含 AXRaise、激活及可选私有聚焦路径。它可以通过提前聚焦减少点击问题，但改变了用户要求保留的交互模型，因此不作为候选产品行为。[源码](https://github.com/sbmpost/AutoRaise/blob/cfed9445695d8092a283fa54d9453072978c7262/AutoRaise.mm#L228)、[项目说明](https://github.com/sbmpost/AutoRaise/blob/cfed9445695d8092a283fa54d9453072978c7262/README.md)。

**S**：cliclick revision `e7976889c9f4d401bba887a22b2e139a8687990a` 提供左右键等合成鼠标动作，通过 CGEvent 投递。它可用于理解和比较合成语义，但不是全局真实点击保留、准确窗口命中或可靠 first-click 的成品证明。[左键实现](https://github.com/BlueM/cliclick/blob/e7976889c9f4d401bba887a22b2e139a8687990a/Actions/ClickAction.m)、[右键实现](https://github.com/BlueM/cliclick/blob/e7976889c9f4d401bba887a22b2e139a8687990a/Actions/RightClickAction.m)。

**I**：最简单且最可靠的局部方案，是应用开发者在自身 AppKit/SwiftUI/Electron 视图里正确接收首次点击。它不满足“不修改其他应用”的通用工具目标。全局方案仍需要证明跨进程事件或激活组合的效果。

### 4.4 Electron、Chromium 与 WebKit 的接收策略

**D / S**：Electron 官方 `acceptFirstMouse` 选项默认 false，控制本应用窗口的 Web 内容首次点击；最新审查 revision `bec2821ba7b83e43aefe40f6a36456be57871dfd` 把该值传给窗口实现。说明此策略是 embedder 可以决定的行为，不能假定所有 Electron 应用相同。[官方选项](https://www.electronjs.org/docs/latest/api/structures/base-window-options)、[源码](https://github.com/electron/electron/blob/bec2821ba7b83e43aefe40f6a36456be57871dfd/shell/browser/native_window_mac.mm#L345)。**未核实目标 ChatGPT 的框架，不把它归类为 Electron。**

**S**：Chromium 开发分支固定 revision `ebbea25128026b70e2fec4a85ff3a9043dcc9093` 的 `render_widget_host_view_cocoa.mm` 858–875 行，检查后台应用中的 CGEvent source PID；source PID 非零且不是本进程时，`acceptsFirstMouse:` 返回 YES。作者注释将其解释为对直接跨进程投递点击的处理。[固定源码](https://chromium.googlesource.com/chromium/src/+/ebbea25128026b70e2fec4a85ff3a9043dcc9093/content/app_shim_remote_cocoa/render_widget_host_view_cocoa.mm)。

**S**：本机 Chrome 的版本标签 `155.0.8059.79` 对应源码 857–861 行，没有上述 source PID 分支，仍取决于 `acceptsMouseEventsOption`。[对应版本源码](https://chromium.googlesource.com/chromium/src/+/refs/tags/155.0.8059.79/content/app_shim_remote_cocoa/render_widget_host_view_cocoa.mm)。标签对照不是本机二进制的完整源码审计，也不是运行测试。

**I / H**：这为无需先激活的 PID 投递 D 提供了具体研究依据，但尚未证明本机 Chrome、Safari、Firefox、ChatGPT 会实际执行点击，更没有证明原始事件拷贝投递时 provenance 会符合该条件。不能伪造别的进程来源、把合成来源冒充硬件来源，或把新分支认定为所有 Chromium 产品已经发布的契约。

**S**：WebKit revision `3e810703e9c67a4a3a40c1c746c0e1e11a1dc6b7` 的 `WebViewImpl::acceptsFirstMouse` 先检查后台拖动/滚动条件，必要时继续询问页面。它证明 Web 内容接收可能有比简单 NSView 开关更细的策略。开发分支不能直接代表 Safari 27.0.1 的实际结果。[WebKit 固定源码](https://github.com/WebKit/WebKit/blob/3e810703e9c67a4a3a40c1c746c0e1e11a1dc6b7/Source/WebKit/UIProcess/mac/WebViewImpl.mm#L2471)。

## 5. 候选技术路线比较

表中性能与覆盖均是基于机制的预估 **I/H**，不是测试结论。所有候选必须先与“关闭工具”的真实鼠标基线比较。

| 路线 | 首次操作与左右键 | 应用覆盖 | 双击、拖动、修饰键 | 延迟、CPU 与可靠性 | 权限和系统干预 |
| --- | --- | --- | --- | --- | --- |
| **A：点击时提前激活准确窗口，放行真实事件** | H：若在目标判定前完成激活，可能执行原操作；左、右分别验证，右键不应额外破坏现有菜单 | I：不依赖业务控件动作，潜在覆盖较广；窗口与应用激活时序仍可能因框架不同而失败 | I：最有希望保留原语义；提前排序仍可能改变后台拖动、Cmd 点击和模态行为 | I：鼠标触发、无轮询可低空闲成本；AX 往返会增加回调耗时并造成竞态；无可承诺毫秒数 | 公开 Session/Annotated tap + 公共激活/AX 候选；TCC 按实测能力请求；不需要 SIP 修改 |
| **B：AX 命中后执行 AXPress / AXShowMenu** | D/H：支持动作的控件可直接执行语义操作，不构造鼠标事件；AXShowMenu 不是任意右键的完全替代 | I：普通可访问按钮可能较好；canvas、自绘控件、缺失 AX 动作及部分网页行为受限 | D/I：接口没有完整鼠标序列参数；立即 press 会破坏按住、拖出取消、双击与带修饰键操作 | I：多次 AX IPC；超时与不确定完成可能导致重复；无法仅按错误安全降级 | AX 客户端授权；跨应用 AX 不符合受支持的 App Sandbox 能力；无需私有 API |
| **C：吞掉原事件，激活确认后重新投递** | H：激活后可能绕开 first-mouse 消耗；可实现左右，但必须准确保留成对事件 | I：不依赖控件业务动作，潜在覆盖广；激活失败、指定窗口困难及合成接收策略仍限制 | I：必须处理 down/up/drag/click count/flags/顺序；只补一次 click 很容易重复、丢失或误触 | I：等待激活带来延迟，事件队列与恢复更复杂；回环及 watchdog 是主要风险 | 监听/过滤、投递和可能的 AX 权限；公共 API 即可研究，不保证成功 |
| **D：无需先激活，直接向命中 PID 投递** | S/H：新 Chromium 源码有支持线索；PID 投递本身不保证目标控件接受或指定窗口命中；左右均待测 | I：可能有较好的部分框架覆盖；当前版本间差异明显，不能成为“仅浏览器适配”的核心承诺 | I：仍是重新投递，必须保存序列、目标窗口关联和来源语义；拖动投递路径需独立验证 | I：可省去激活等待；同一 PID 多窗口、事件来源、菜单及控件拒收影响可靠性 | 公共 postToPid 与命中能力；可能需要 AX；无需修改目标应用 |
| **E：修改自身视图策略 / 与应用协作** | D：本应用通过 acceptsFirstMouse / SwiftUI / Electron 可直接支持；不用重放 | D/I：只覆盖自己控制或愿意协作的应用，不能满足全局目标 | I：由原应用保持自然语义，仍需测试自身控件 | I：直接、成本小；仅作为机制正对照或长期上游改进 | 不需要全局拦截；不将修改其他应用当产品方案 |
| **F：改写事件公开字段后直接返回** | D/H：可以修改字段；没有文档保证目标 PID/命中字段改写会强制接受首次点击 | H：未找到可引用的普遍成功证明 | H：字段改写可能改变路由与配对，必须隔离验证 | H：理论上干预小；证明负担高，不能依据字段名称选择 | 不使用未公开数字字段；若只靠未保证行为稳定性不足 |

### 5.1 与 yabai、skhd、Karabiner-Elements 的共存

**S / I**：路线 A 的主要风险是提前激活触发 yabai 的焦点信号、重排或窗口移动；路线 C/D 的主要风险是截获 yabai 保留的组合键、重投被再次消费、顺序改变。B 还可能与物理 up 同时触发动作，产生重复。

Phase 1 必须验证：不同启动顺序；yabai 正在运行且其鼠标 move/resize 保持有效；skhd 快捷键和焦点切换与点击交错；Karabiner 将按钮/修饰键重新映射后的最终事件语义。**现有工具共存不等于本应用可以覆盖或改写其配置。** 不设置 FFM，不用 hover 提前 focus，不把关闭 yabai 作为正式解决办法。

### 5.2 无重放是否可行

- **D**：自己控制的 AppKit/SwiftUI 视图可以原生接受首次点击；合作应用也可自行改变策略。
- **D/H**：AX 动作无需鼠标重放，但不等价于完整鼠标操作；只对目标提供的语义能力成立。
- **H**：第三方全局工具通过点击时公开 API 激活再放行真实事件，存在可实验的路径；Apple 没有提供跨进程排序成功的保证。
- **D/I**：把原始 CGEvent 拷贝后 `post`/`postToPid`，即使不新建 mouse event，仍属于重新投递，不能宣传为“完全保留真实事件、没有重放”。

## 6. TCC、App Sandbox、SIP 与事件可信度

1. **D / DTS**：监听、投递、AX 操作是不同能力，分别检查。Apple DTS 2026 解释 Accessibility 授权通常已提供事件 posting 和 listening，而 Input Monitoring 提供 listening，因此不应默认强制用户重复授予两种权限；以实际 preflight、tap 创建和 AX 操作结果为准。[Apple DTS](https://developer.apple.com/forums/thread/828052)。
2. **D / DTS**：受支持的沙盒应用可以用输入监听路径做观察；但官方 App Sandbox 文档把辅助应用使用 Accessibility API 列为不兼容功能。若最终方案需要跨应用 AX，优先评估签名、公证的沙盒外分发，不假定存在通用沙盒 entitlement。[官方 App Sandbox 限制](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)、[监听的 DTS 解释](https://developer.apple.com/forums/thread/811443)。签名、公证、Hardened Runtime 与 App Sandbox 是不同概念。
3. **D / I**：本项目选用公开 API 的候选路径不以关闭 SIP、注入或修改系统为前提；不能因为参考了 yabai 就继承其私有能力或系统修改要求。
4. **DTS**：不能通过 `CGWindowListCopyWindowInfo` 是否含窗口名称/owner name 来推断 Screen Recording 权限；这些键的权限门控细节并非该 API 的稳定契约。使用正式权限检查；单纯鼠标交互不预先请求截图权限。[macOS 27 相关 DTS 说明](https://developer.apple.com/forums/thread/839069)。
5. **D / H**：CGEvent 有来源字段，目标可以存在自己的接收判断；TCC 授权不是“所有目标把合成事件当成硬件事件”的承诺。浏览器中的 `isTrusted`、用户激活及剪贴板策略要实际检查。不能武断宣称 AX 或 CGEvent 一律产生不可信 DOM 事件，也不能武断宣称它们一律等同真实用户输入。[公开字段](https://developer.apple.com/documentation/coregraphics/cgeventfield)、[Clipboard 规范](https://w3c.github.io/clipboard-apis/)。
6. **D / H**：AppKit 2026 更新提及通用剪贴板读取提示的方向。复制验收应优先在专用验证输入框中粘贴并核对预期文本，而不是让运行时引擎为判断点击成功持续读取用户剪贴板。[AppKit 更新](https://developer.apple.com/documentation/updates/appkit)。

权限验证必须使用稳定 bundle/signing 身份；干净环境与撤销授权属于单独实验，不能把开发机已有 TCC 缓存当作新安装体验的证据。调研阶段没有提示授权、读取 TCC 数据库或重置现有授权。

## 7. 推荐的验证路线与关键假设

**建议进入 Phase 1 的研究型 PoC；不建议直接开始菜单栏产品、配置页面或全局重放引擎。**

验证顺序：基线和观测 → A 保留真实事件 → B AX 语义动作 → D 无先行激活的 PID 投递 → C 激活后完整序列重新投递。A 优先来自用户要求的自然输入语义；B/D 用来判断是否能避免激活或减少等待；C 作为干预更大的独立比较。实验可以推翻这一优先级。

| 假设 | 怎样推翻或证实 | 为什么影响选型 |
| --- | --- | --- |
| H1：公开激活/AX 操作在 down 放行前足以让目标处理真实首次点击 | 比较目标窗口状态、原始事件序列与实际按钮/链接/剪贴板结果；出现仅激活而未执行即失败 | 决定 A 是否有资格作为主候选 |
| H2：Session / Annotated tap 能给出稳定、准确目标信息 | 比较事件位置、公开命中窗口字段、NSWindow 命中与 AX 顶层命中；覆盖重叠、弹层、多屏与透明区域 | 避免点击被送到坐标下错误窗口 |
| H3：关键应用提供有效 AX 动作且不会重复执行 | 真正复制、导航或改变控件状态，验证 unsupported/cannotComplete、按住及拖出取消 | 判断 B 是否只能作为局部选项，以及混合策略是否安全 |
| H4：postToPid 无需激活即可让业务控件执行 | 分别测本机版本和源代码支持线索；区分拷贝原事件与用官方事件来源重新构造的序列 | 决定 D 的覆盖，不把新 Chromium 逻辑误当普遍契约 |
| H5：重新投递完整序列保持点击数、拖动、修饰键和菜单正确 | 记录每个逻辑手势和实际业务结果；一次动作对应一次执行；无缺失 up 或递归 | 决定 C 的成本是否值得 |
| H6：所有候选可与现有工具共存 | 不同启动顺序及 yabai move/resize、skhd、Karabiner 重映射测试 | 防止通过破坏现有功能获得表面成功 |
| H7：开销和延迟满足体验要求 | 测回调耗时、动作延迟分位数、空闲 CPU、tap 禁用次数，使用相同实验条件 | 不能凭“原生”或“Swift”推断低延迟 |
| H8：权限行为在新身份/干净系统可复现 | 稳定身份测试已授权、未授权、撤销、重启；与开发机缓存结果分开 | 决定部署和失败恢复可行性 |

具体操作、真实鼠标来源要求、应用矩阵、试次和判定规则见 [Phase 1 验证协议](PHASE_1_VALIDATION_PLAN.md)。**该文档是实验计划，所有结果均未执行，不构成 Phase 2 架构批准。**

## 8. 已确认的系统边界与仍未知的部分

| 结论 | 证据等级 | 对产品的影响 |
| --- | --- | --- |
| 首次点击接收是命中视图/框架可决定的策略；部分控件原本接受 | D / S | 禁止对所有后台点击无条件再补一次点击 |
| AppKit global monitor 只能异步观察其他应用事件 | D | 不能靠该接口保证抢在原点击前完成修改 |
| 普通应用激活是请求；协作 yield 只能由活动应用影响上下文 | D | 不以激活调用返回值当作当前事件可执行的排序屏障 |
| AX 可以命中和执行目标声明的动作，但动作可不受支持 | D | 无法由 AXPress 单一路线承诺任意控件及完整鼠标语义 |
| AX 的 cannotComplete 可能并不表示动作没有执行 | D | 自动“AX 失败 → 鼠标补击”不是安全默认策略 |
| AXMain 不等于 key focus；AXFocused 不等于动作执行 | D / L | 聚焦日志必须与业务效果证据分离 |
| PID 投递不指定具体窗口，也不返回动作完成回执 | D / L | 同应用多窗口和真实执行必须实验 |
| tap 可以被系统因无响应等原因禁用 | D | 最终引擎需要可观测恢复；失败不能吞掉整个鼠标流 |
| 跨应用辅助 AX 不属于受支持的 App Sandbox 功能 | D / DTS | 分发路径存在明确约束，不能混同于关闭 SIP |
| 没有找到公开全局 first-click 开关或跨进程激活/事件原子事务 | 有范围的检索结果 / I | 不能预先承诺完全通用；不是数学意义的不可行证明 |
| A/C/D 在当前目标应用是否可靠、左右键及组合语义是否成立 | H | 留待 Phase 1；本轮未验证 |

**Phase 0 允许推进的下一步是最小可行性实验。最终 API、混合策略、状态机和兼容模式仍全部待定。** 只有实测发现具体覆盖缺口后，才能讨论兼容模式；不得用应用白名单或针对 ChatGPT 复制按钮的硬编码替代通用研究。

## 9. Phase 0 交付与后续门槛

| 用户要求 | 本轮交付 |
| --- | --- |
| 最新 Apple API 清单和官方链接 | 第 2 节；官网 DocC/Markdown 与 SDK 27 交叉审查 |
| 后台首次点击机制 | 第 3 节；区分系统流、应用、窗口、视图与网页接收策略 |
| 官方示例与开源实现、局限 | 第 3.2、4 节；固定源码 revision，不复制现成实现 |
| 至少三条指定路线及其他发现 | 第 5 节 A–F；覆盖左右键、框架、组合操作、性能、权限与工具共存 |
| 推荐及技术依据 | 第 1、7 节；推荐实验顺序，不预定正式架构 |
| 实验关键假设 | 第 7 节 H1–H8，附完整验证协议 |
| 已确认系统限制 | 第 8 节；将已确认边界和未知运行结果分开 |
| 禁止提前开发与旧系统兼容 | 当前仅文档；目标固定 macOS 27；不生成 Swift、PoC 或应用工程 |

Phase 1 必须提交实际执行结果及失败证据。Phase 2 再以这些结果选择核心公开 API，判断是否需要混合策略、事件状态机和可说明的兼容模式；若核心目标不可满足，也应如实记录。Phase 3 才实施菜单栏、配置、全局引擎、权限管理、恢复、性能优化、测试与分发。

本轮没有证明 ChatGPT 复制成功，没有执行任何运行时点击测试，没有基准测试、应用构建或签名分发结果。
