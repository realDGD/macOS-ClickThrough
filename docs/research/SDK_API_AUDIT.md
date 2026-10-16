# 本机 macOS SDK 27 API 审查记录

日期：2026-10-14。证据类型：**L（本机只读检查）及 D（SDK 声明/注释）**。状态：静态审查，没有建立 event tap、调用 AX 动作、激活其他应用或投递鼠标事件。

环境为 macOS 27.0.1 / 26A434、Xcode 27.0 / 27A266a、SDK macosx27.0、arm64。SDKSettings.json 的 Version 为 27.0。研究目录原先为空且不是 Git 仓库。

## 1. 可核对的接口位置

表中行号来自本机文件，完整 SHA-256 和符号匹配位置保存在 [证据索引](EVIDENCE_INDEX.json)。哈希只固定本次检查的 SDK 内容，不证明运行时效果。

| 文件 | 相关位置与结论 | SHA-256 前 12 位 |
| --- | --- | --- |
| CGEvent.h（本地 SDK：`System/Library/Frameworks/CoreGraphics.framework/Headers/CGEvent.h:296`） | 296：全局 tap；315：PID tap；343：tap 内投递；372：PID 投递；399–408：监听/投递权限检查与请求。269–270 的 HID/root 注释与开源实践有差异，留待实验。 | `82c0ad9eb7c2` |
| CGEventTypes.h（本地 SDK：`System/Library/Frameworks/CoreGraphics.framework/Headers/CGEventTypes.h:349`） | 349–356：目标/来源 PID 及 user data；377–378：两个公开窗口命中字段。没有声明强制接受首次点击的全局 flag。 | `0eb5b0aca9a7` |
| CGEventSource.h（本地 SDK：`System/Library/Frameworks/CoreGraphics.framework/Headers/CGEventSource.h:185`） | 185–205：本地硬件过滤默认不抑制；228–238：默认 suppression interval 为 0.25 秒。不能仅凭后者声称投递必然阻塞真实输入。 | `20bf22c7d7a1` |
| NSView.h（本地 SDK：`System/Library/Frameworks/AppKit.framework/Headers/NSView.h:225`） | 225–226：acceptsFirstMouse 与 shouldDelayWindowOrdering；493、575–583：macOS 27 手势拖动与排他行为，均为应用内视图能力。 | `af91fb647759` |
| NSEvent.h（本地 SDK：`System/Library/Frameworks/AppKit.framework/Headers/NSEvent.h:496`） | 496：macOS 27 touch swipe 设置；global/local monitor 接口仍属于事件观察/本进程过滤，没有全局 first-click override。 | `fe7611bf4929` |
| NSWindow.h（本地 SDK：`System/Library/Frameworks/AppKit.framework/Headers/NSWindow.h:634`） | 634–636：屏幕位置下的窗口命中编号接口。没有从这里取得其他进程 NSWindow 对象的能力。 | `32d8533578a7` |
| NSRunningApplication.h（本地 SDK：`System/Library/Frameworks/AppKit.framework/Headers/NSRunningApplication.h:27`） | 27：ignoringOtherApps 已弃用且无效；144：协作激活；146–148：普通激活被说明为请求成功发送，不能用返回值代替点击动作或事件排序验证。 | `b7fa5d5b933a` |
| NSApplication.h（本地 SDK：`System/Library/Frameworks/AppKit.framework/Headers/NSApplication.h:231`） | 231–254：激活和 yield；当前活动应用控制协作激活上下文。应用内 sendEvent/postEvent 不等于远程视图操作。 | `33ed7a975710` |
| NSControl.h（本地 SDK：`System/Library/Frameworks/AppKit.framework/Headers/NSControl.h:168`） | 168–194：macOS 27 新增控件事件类型及观察入口。不是外部进程全局接管业务动作的 API。 | `97801b3a7c4d` |
| AXUIElement.h（本地 SDK：`System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Headers/AXUIElement.h:315`） | 55–64：信任与异步提示；283–295：动作枚举；315–331：动作执行与不确定完成；334–353：按 z-order 的跨应用命中；387–402：消息超时。 | `10f58138ceb5` |
| AXActionConstants.h（本地 SDK：`System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Headers/AXActionConstants.h:34`） | 34–40：AXPress；99–114：AXRaise/AXShowMenu。动作接口没有原始鼠标位置、click count、修饰键或拖动序列参数。 | `d7c61e15b057` |
| AXAttributeConstants.h（本地 SDK：`System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Headers/AXAttributeConstants.h:573`） | 573–587：公开 AXWindow 关联；478–493：可聚焦属性；805–818：AXMain 明确不蕴含 key focus。 | `5734d01bc751` |
| arm64e-apple-macos.swiftinterface（本地 SDK：`System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface:2456`） | 2456–2464：allowsWindowActivationEvents 两种形式；12172–12173：NSHostingView 的 first-mouse/ordering 方法。内部 SDK 存在旧系统分支不代表本项目需要写兼容代码。 | `155b00c7d8fa` |
| IOHIDManager.h（本地 SDK：`System/Library/Frameworks/IOKit.framework/Headers/hid/IOHIDManager.h:470`） | 470–482：设备输入值回调。检查到的接口作用于设备输入，没有提供远程窗口 first-mouse 策略。 | `ffdc393a3d21` |

## 2. 对结论有影响的细节

- 当前网页 activate(options:) 的返回值描述与 SDK 的“请求成功发送”措辞粒度不同；官方协作激活文章明确系统决定是否授予激活。实验应同时观察实际状态和业务执行，不以 Bool 作为跨进程同步屏障。
- CGEventPostToPid 的网页正文很少；SDK 的投递章节说明按应用路由，并经过该进程 taps。没有窗口参数或业务动作完成回执。
- AXMain 不是 key focus；设置 AXFocused 不等于 AXPress。它们应分开作为实验变量。
- AXUIElementCopyElementAtPosition 明确按窗口 z-order 命中；kAXWindowAttribute 提供公开的所属窗口关联。无需先采用 Hammerspoon/yabai 的私有窗口编号接口。
- AX action 的 cannotComplete 可以发生在动作已经开始、目标进入模态处理的情况下，不能视为“可以放心再点击”的证据。
- SwiftUI allowsWindowActivationEvents 在当前 SDK/文档中可用，但它是自身视图层级配置。不能用于远程改写 ChatGPT 或其他应用。
- macOS 27 在这些相关头文件中新增的输入能力主要涉及控件事件、触控及手势。CGEvent 三份核心头文件和 AX 三份头文件中未检出 `API_AVAILABLE(macos(27...))` 的新增声明；这是限定文件和检索形式的结果，不代表扫描了整个系统全部 API。

## 3. 方法与限制

使用 sw_vers、xcodebuild、xcrun、SDKSettings.json，以及 rg 和逐段读取进行静态检查。未编译 Swift 样例或 PoC；没有因读取头文件而获得任何运行时权限证明。

Apple 当前参考、官方示例和开源来源见 [完整报告](PHASE_0_RESEARCH.md)。本记录与报告共同支撑 Phase 0，不替代 [Phase 1 验证](PHASE_1_VALIDATION_PLAN.md)。
