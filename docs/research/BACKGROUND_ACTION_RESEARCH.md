# 后台按钮操作：不 raise 的 API 调研与最小实验

日期：2026-10-15，Asia/Makassar。目标 macOS 27。本文在新 PoC 编写之前完成；A4 源码与可执行文件保持不变。本轮只研究普通按钮，关键点击由用户物理输入产生，不扩大到更多软件或完整手势。

**当前状态：用户已要求暂停此需求实验，保留为未来探索。独立探针已退出，源码、构建和日志保留；不继续任何临时焦点或 PID 投递实验。下文的路线与下一步仅为历史记录。项目主线已返回 A4 的 Phase 2。**

## 结论与路线选择

**先验证 AXPress 对后台普通按钮的实际操作，再根据结果决定是否进入 PID 定向投递。** 当前没有找到 Apple 保证可全局强制任意应用“接受点击且不激活／不前移”的公开开关。这个检索结论不等于证明所有公开 API 组合都不可能。

这里将“不 raise”按较严格条件记录：按钮业务执行一次，原前台应用不变，目标窗口与其他普通窗口的相对顺序不变。应用可以自行改变窗口；接口返回值不能保证这些条件成立。窗口顺序的离散采样也不能排除采样之间的瞬间变化。

## Apple 公开能力与保证范围

| API | Apple 明确提供的能力（D） | 本项目的判断或待验证部分（I/H） |
| --- | --- | --- |
| AXUIElementCopyElementAtPosition（本地文件 `docs/research/background-action-sources/AXUIElementCopyElementAtPosition.json`，未公开） | 以屏幕左上角为基准命中 AX 元素；考虑窗口 z-order；system-wide 对象不限应用 | 可定位可见按钮，不需要按应用或按钮名称硬编码。遮挡区域不能据矩形猜测穿透。 |
| [AXUIElementCopyActionNames](https://developer.apple.com/documentation/applicationservices/1462053-axuielementcopyactionnames) | 返回元素实际支持的动作，可能为空 | 根据能力决定是否支持，不能假定所有按钮或网页都暴露 AXPress。 |
| [kAXPressAction](https://developer.apple.com/documentation/applicationservices/kaxpressaction)、[AXUIElementPerformAction](https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction) | 请求元素执行单击语义；可返回 unsupported、cannotComplete 等错误 | 无需由工具先请求 AXFrontmost／AXMain，但没有“目标应用绝不自行激活”的保证。不能完整替代按住、拖动、双击、修饰键。 |
| 同上：cannotComplete | 目标可能在处理模态动作，超时不一定代表动作未执行 | 不重试、不自动补鼠标点击，不静默回退 A4。 |
| [AXUIElementSetMessagingTimeout](https://developer.apple.com/documentation/applicationservices/1459345-axuielementsetmessagingtimeout) | 设置本进程全局或单个 AX 对象的消息超时 | 每次消息超时不是整个动作流程的总延迟上限。 |
| [CGEvent.postToPid](https://developer.apple.com/documentation/coregraphics/cgevent/posttopid(_:)) | SDK 27 有公开投递入口；CGEvent.h 将其列为 PSN 定向投递的替代；投递进入目标进程事件流 | API 不指定窗口、返回 void，不保证 first-mouse 接受、动作完成或不 raise。复制事件再投递仍属于重新投递。 |
| [NSView.shouldDelayWindowOrdering](https://developer.apple.com/documentation/appkit/nsview/shoulddelaywindowordering(for:))、[NSApplication.preventWindowOrdering](https://developer.apple.com/documentation/appkit/nsapplication/preventwindowordering()) | 应用自身处理 mouse-down 时可以延迟／阻止通常的窗口前移 | 是目标应用内部能力，不能把本工具的 NSApp 当成其他进程的 NSApp。只作为机制依据，不是全局远程开关。 |
| AX 信任与事件 tap | AXIsProcessTrustedWithOptions 的提示异步发生，不改变即时返回结果；主动 tap 可删除原事件 | 新 PoC 使用独立 bundle，需要实际检查自己的 TCC；不继承 A4 的授权结论。 |

官方原文、检索时间和 SHA-256 见 [source-index.json](background-action-sources/source-index.json)。postToPid 的当前 DocC 页面只有声明，语义范围结合本机 SDK 27 的 CGEvent.h:356–374；不补造官方保证。

## 开源与既有源码证据（S）

- [Hammerspoon AX 动作接口](https://www.hammerspoon.org/docs/hs.axuielement.html#performAction) 使用元素声明的动作；其文档也说明返回成功不保证实际动作完成。它提供封装，不提供额外的不 raise 系统契约。
- [Chromium 固定 revision ebbea251](https://chromium.googlesource.com/chromium/src/+/ebbea25128026b70e2fec4a85ff3a9043dcc9093/content/app_shim_remote_cocoa/render_widget_host_view_cocoa.mm#858) 在 acceptsFirstMouse 中处理其他进程直接投递的事件，注释指出它与 WindowServer 常规路由的激活点击不同。这使 PID 路线值得研究，但只是该源码的行为依据。
- [本机 Chrome 155.0.8059.79 对应标签](https://chromium.googlesource.com/chromium/src/+/refs/tags/155.0.8059.79/content/app_shim_remote_cocoa/render_widget_host_view_cocoa.mm#857) 不含上述 source PID 分支。不能把新分支当作本机 Chrome 的能力，也不为本轮更换浏览器。
- 当前 FirstClickTarget 自绘视图使用 AXGroup，未实现 press 动作。AXPress 不适用是该靶标的预期能力边界；保留它原样，不为让 AX 路线通过而改造它。
- A4 请求 AXMain／AXFrontmost，原始点击仍正常流经系统。删去 AXRaise 无法产生本选项，因为 A4 本来没有调用 AXRaise；原事件本身也可能触发通常的激活与前移。

## 候选比较

| 路线 | 可行性判断 | 限制与本轮处理 |
| --- | --- | --- |
| B：AXPress 后台按钮 | D 支持语义动作，I 认为是“单纯按钮”的最短路径，H 为不 raise 与真实执行 | 首轮优先。只验证普通无修饰键左键按钮；不承诺任意控件。 |
| D：PID 定向投递 | D 公开投递，S 有 Chromium 处理线索，H 为本机实际行为 | AX 结果保存后再决定是否测试；不与 B 混合，不伪造别的 PID 或硬件来源。 |
| 目标应用合作阻止 ordering | D 支持自身窗口，I 认为语义自然 | 不修改第三方应用，不作为本工具的全局实现。 |
| A4 后恢复原窗口顺序／焦点 | I 无法满足“始终不 raise”，仍会经历激活与前移，可能闪动和扰动窗口管理器 | 本轮不采用。 |

## 首轮实验：一次性 AX 按钮捕获

这是一项已由用户授权的可丢弃可行性实验，不是正式架构或菜单栏产品。

1. 独立目录、独立 app 与日志；不重建 A4。先保存 A4 源码／二进制哈希。新实验布置好后暂停 A4，避免两个引擎同时处理。
2. UI 填入本次目标 PID，仅用于限定实验窗口来源，不是产品应用白名单。点击“准备一次”后，其他进程及探针自身点击照常通过。只接管该目标的普通层、无修饰键、跨应用后台单击。
3. 捕获 down，等待同一手势 up；拖动超出小范围或停止时取消动作，并配对消费 up。每次最多执行一次。原始 down/up 不再发送给目标，防止正常路由激活或重复操作。
4. 释放鼠标后立即撤下 tap，再 AX 命中与检查动作，避免 AX IPC 堵塞活动 tap。只有命中 PID 一致、按钮角色且声明 AXPress 才执行；不读取／匹配业务名称。命中按钮子元素时仅有限向上寻找按钮。
5. 只调用一次 AXPress。错误／不支持时记录并结束本次，不补击、不激活、不恢复叠放。
6. 记录业务日志对应的试次、前台 PID、普通窗口 ID 顺序；动作后作有限快照并监听应用激活通知。首轮 Chrome 既有诊断页普通按钮只需一个明确试次；操作由用户真实鼠标完成。
7. 通过条件是按钮恰好 +1，原前台应用不变，目标窗口未前移。支持动作、API 成功、构建或权限通过都只是前置证据。

首轮不新增安装软件、不测更多浏览器，不扩展右键、输入框、完整拖动或性能矩阵。若候选失败，先按现有日志作出机制判断；不以追加相近试次替代结论。

## 首轮实际结果：Chrome 普通按钮局部可行

R：用户反馈“2→3；没有 [Chrome 前移]；是的 [Codex 仍前台]”。按独立网页计数配对，这对应新探针 **trial 4**，不是最早的 trial 1。页面 session 为 `fc5f317f-3fb3-46fa-813a-d595798cd1f7`，系统事件号 3562。

该次只有一组捕获 down/up、一次 AXPress 请求及一次 `button_action`，计数由 2 变为 3。API 返回 0；业务是否执行以网页操作记录为准。动作前、返回后、0.2 秒及 0.8 秒快照的前台 PID 都是 Codex 77884，普通窗口 ID 顺序完全一致，观察区间没有应用激活通知。用户反馈与日志一致，支持这个普通按钮在后台执行且不 raise。离散快照仍不能证明任何瞬间都未发生过排序变化。

R：同一段日志中另有 trial 2/3/5/6 的网页计数增量观测，前台及顺序采样保持不变。其中 trial 6 前台来源不同；未让用户逐项标注，不把它们计为额外受控成功试次或统计样本。

R：早期 **trial 1** 的 AXPress 虽返回 0，但 Chrome 随后成为前台并移到 Codex 之前；该次没有配对到诊断按钮业务日志，确切控件身份未知。保留为未解决边界，不能改称“所有 AXPress 都不会 raise”，也不能擅自归因于某个浏览器工具栏按钮。

结果与原始配对快照见 chrome-button-axpress-result.json（本地文件 `poc/background-action/runs/20261015-103011/chrome-button-axpress-result.json`，未公开）。核对时新探针已自动停止，A4 仍停止，A4 源码及二进制 SHA-256 与实验前一致。

I：普通按钮的局部可行性问题已有正面证据，不重复这个步骤。下一项只在现有 Chrome 中验证真实 ChatGPT 网页代码复制：重新准备剪贴板对照、单次后台复制、有效粘贴匹配，同时检查前台／窗口状态。尚未实施该业务试次，不增加其他软件。

## 后续复制结果与暂停时的保留结论

R：用户重试后的网页验证 **试次 2 不匹配**，Chrome 没有前移、Codex 仍在前台；网页提示“无法复制到剪贴板”“内容未复制。请在 ChatGPT 处于焦点时重试”。独立验证日志有一次成功准备与一次有效不匹配；该区间只有探针 **trial 13 / event 3666** 的一次 AXPress 请求，返回 0。动作前后及延后采样均保持 Codex 前台和相同窗口顺序。该结果为**业务失败**，不能以 AX 成功代替复制成功。

结果保存于 web-copy-trial2-result.json（本地文件 `poc/background-action/runs/20261015-103011/web-copy-trial2-result.json`，未公开）。之前的网页试次 1 及额外探索捕获保留在原日志，不擅自合并成受控重复试次。

S：本机 Chrome 对应版本源码的 `ClipboardPromise::RejectIfDocumentNotFocused` 检查文档焦点；除代码中指定的可信表面例外外，未聚焦时返回 `NotAllowedError`。W3C 当前 Clipboard API 工作草案也描述异步剪贴板的文档焦点条件。原文和哈希见 [clipboard-focus-source-index.json](background-action-sources/clipboard-focus-source-index.json)。这是源码／草案依据，不是对 ChatGPT 内部 JavaScript 的审计。

I：用户看到的提示与该焦点限制一致；确切失败由网页预检还是浏览器拒绝后处理产生，未独立确认。不能仅靠 AXPress 或假定换成 PID 投递便解除页面焦点要求。

用户随后澄清未来目标是“窗口不前移即可，允许短暂切换焦点”，但在任何新实验开始前明确要求暂停。此放宽条件尚未验证，既有失败不等于证明“不改变窗口叠放、暂时切焦点”也不可能。恢复需要新的明确指令；当前不继续设计或试验该路径。
