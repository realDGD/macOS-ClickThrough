# 激活上下文对照与公开 API 补充调研

日期：2026-10-14。阶段：Phase 1 的研究补充；**本报告完成时尚未实现 A3，A3 功能结果 NOT_RUN。** 不改变最低 macOS 27、不使用私有 API、不修改其他应用、不预定正式架构的约束。

证据标签：D 为 Apple 文档或 SDK 明确说明；S 为固定版本源码；R 为用户物理鼠标操作与独立靶标日志共同支持；H 为尚未验证的假设；I 为分析推论。

## 1. 已完成的激活上下文实验

| 当前 A1 的点击前前台来源 | 激活调用返回值 | 拒绝首次点击靶标的实际操作 | 证据 |
| --- | --- | --- | --- |
| Codex，探针在后台 | false | 保持 0，未收到操作所需 down/up | R：用户结果、探针与靶标日志 |
| Chrome，探针在后台 | false | 1 → 1；仍调用 acceptsFirstMouse 并拒绝 | R：event 2044，sequence 380 |
| FirstClickProbe 自身 | true | 0 → 1 | R：event 2036，sequence 372；独立 down/up、action_executed=true |
| FirstClickProbe 自身，复核 | true | 1 → 2 | R：event 2057，sequence 393；独立 down/up、action_executed=true |

上述探针事件字段检查均未变化，代码返回同一个 CGEvent；实验期间代理只读取证据，计数来自用户真实鼠标。原生靶标的 acceptsFirstMouse 策略未修改。

R：以 Codex 为前台来源的 A2 中，AXMain 设置返回成功，随后普通应用激活仍返回 false，左侧未执行。右侧接受首次点击的正对照在停止、A1、A2 下分别累计到 1、2、3。

I：当前普通 activate 的可行性依赖已测激活上下文，不能作为任意前台应用下的通用实现。受控条件已证实可以保留真实事件并执行拒绝控件，但两次成功不足以保证所有应用或每次调度都成立。当前数据没有给出 false 的唯一原因，也没有证明全部公开 API 路线不可能。

D：Apple 的[协作激活说明](https://developer.apple.com/documentation/appkit/passing-control-from-one-app-to-another-with-cooperative-activation)说明激活是由系统按上下文裁决的请求，活动应用可以先 yield。现有 A1/A2 并未执行 yield，不能把后台普通请求视为完成了协作激活。调用 activate 的 Bool 与操作执行分别记录。

## 2. 新补查的公开入口

| API | Apple 明确提供的能力 | 未保证的部分 |
| --- | --- | --- |
| [kAXFrontmostAttribute](https://developer.apple.com/documentation/applicationservices/kaxfrontmostattribute) | D：应用级 AX 对象的属性，表示应用是否 active；当前 SDK 27 有公开声明 | 文档未保证任意应用均可写，更未保证在当前真实鼠标事件处理前完成激活 |
| AXUIElementIsAttributeSettable / AXUIElementSetAttributeValue | D：动态检查属性可写性并写入；错误包括不支持、消息无法完成、API 禁用 | 写入成功不是控件已经执行，超时也不是完整事务回滚 |
| NSAccessibilityProtocol.accessibilityFrontmost | D：当前 AppKit SDK 27 中是带 setter 的 BOOL 属性，表示应用 active | 这是服务端协议能力，不能单凭此声明断言所有跨进程应用对象可写 |
| [NSWorkspace.openApplication(at:configuration:completionHandler:)](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication(at:configuration:completionhandler:)) | D：按应用 URL 打开，异步报告结果；OpenConfiguration 默认复用已有实例 | 文档没有给出先于此刻鼠标分派的完成屏障 |
| [NSWorkspace.OpenConfiguration.activates](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/activates) | D：控制是否将应用带到前台，默认 true | 不保证某个后台窗口的命中控件接受正在通过的首次点击 |

关键区别：SDK 的 kAXMainAttribute 描述明确指出，非活动应用也能有 main 窗口，main 不一定意味着 key focus。A2 的 AXMain 成功不能代替应用 active 的验证。

SDK 27 的 owning source：

- AXAttributeConstants.h:1005（本地 SDK：`System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Headers/AXAttributeConstants.h:1005`）：AXFrontmost；同文件 805 行起为 AXMain 的语义。
- AXUIElement.h:205（本地 SDK：`System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Headers/AXUIElement.h:205`）：属性写入能力与错误。
- NSAccessibilityProtocols.h:466（本地 SDK：`System/Library/Frameworks/AppKit.framework/Headers/NSAccessibilityProtocols.h:466`）：frontmost 的服务端读写属性。
- NSWorkspace.h:45（本地 SDK：`System/Library/Frameworks/AppKit.framework/Headers/NSWorkspace.h:45`）：现代异步 openApplication；同文件 163 行起说明 activates。

## 3. 相关开源源码提供的有限证据

S：[node-window-manager 固定 revision d4174d2902a9dc8f2a08f0b692cae26b23507726](https://github.com/sentialx/node-window-manager/blob/d4174d2902a9dc8f2a08f0b692cae26b23507726/lib/macos.mm#L252) 的 bringWindowToTop 创建应用级 AX 对象，设置 AXFrontmost，再设置窗口 AXMain。

该源码证明有窗口管理工具尝试此公开属性组合，不能证明 first-click 已解决。它忽略 AX 返回值，而且整个项目的窗口关联还使用私有 _AXUIElementGetWindow；本项目不采用该私有关联或复制完整实现。A3 继续使用既有公开窗口命中和 PID 获取。

Apple 文档与源码快照及哈希保存在 [source-index.json](activation-context-sources/source-index.json)。AXFrontmost 的 Markdown 入口返回 404，已改读 Apple 官方 JSON 文档并保留失败记录；没有补造内容。

## 4. 推荐的下一个最小验证

I：优先追加独立 **A3：只设置应用级 AXFrontmost**。该入口直接针对此次实验尚未完成的应用 active 状态，调用链短，仍可返回原事件；暂不将异步 NSWorkspace opening 纳入实时回调，也不直接进入事件重放。

H：当探针在后台、Chrome 或 Codex 在前台时，目标应用的 AXFrontmost 可能可写，并且可能在回调返回前让目标正确接收真实点击。这两部分都必须实测。

本次 PoC 的范围限定为：

1. 在现有模式列表追加 A3，用公开 PID 创建应用级 AX 对象；检查 AXFrontmost 可写性后仅写入 true。
2. 设置该 AX 对象的消息超时为 0.025 秒。记录 timeout 设置、可写性、写入与读回状态，以及写入后的前台 PID。每次鼠标 down 尝试一次，不重试、不轮询等待、不回退到 A1/A2 或重放。
3. 继续只处理普通窗口层、无键盘修饰键的 down；保留原 CGEvent、up、drag、click count 与 source 字段。其他输入原样放行。
4. 不设置控件业务值，不调用 AXPress/AXRaise，不修改目标应用，不添加应用白名单。A3 先只改应用 active，不同时添加 AXMain，以保持变量清楚。
5. 保留原生靶标及计数，停止时建立负对照，从 Chrome、Codex 前台各单击左侧一次。只有独立 down/up 与一次操作增量才算该试次执行；AX 返回成功、frontmost 读回和窗口焦点只是诊断。

## 5. 风险、验收与决策边界

- H：AX 属性可能不可写，或者 setter 被应用忽略；逐项记录，不能声称通用覆盖。
- H：设置成功可能仍有时序差，必须以拒绝靶标操作判断，不能把读回 true 当成功。
- D/I：消息调用可能失败或拖慢 tap，现有 tap 禁用时停止并交给人工重启；0.025 秒是单个 AX 对象消息设置，不是完整回调总延迟承诺。
- I：仅应用前台属性不能保证同应用另一个后台窗口成为 key；这项仍待后续独立测试，不为此次小验证添加混合策略。
- R：此前的左右侧数据不覆盖右键、双击、拖动、修饰键、SwiftUI、其他浏览器或 yabai move/resize 兼容性。

验收顺序：先保存本报告；再追加、构建并启动独立 A3 模式；最后交由用户物理鼠标操作并读取靶标日志。构建、签名、权限状态和符号审查只算准备检查。A3 验证前不作 Phase 2 最终架构决策，不开发正式菜单栏产品。

## 6. 报告交付后的 A3 最小实验结果

R：A3 实现后，用户重新授权辅助功能并用真实鼠标测试。探针在后台，Chrome 为前台来源的 event 2149 使拒绝控件计数 4 → 5；Codex 为前台来源的 event 2160 使计数 6 → 7。独立靶标均收到完整 left_down/left_up 并记录一次操作；原事件字段未变。证据见 [运行记录](PHASE_1_A_SESSION.md) 及 配对日志（本地文件 `poc/activation-preserve/runs/20261014-155656/native-a3-background-sources.json`，未公开）。

R：两次 AXFrontmost 均可写、设置成功，但即时读回为 false，写入后读取的前台 PID 未变。I：不能将即时读回或 API success 当作同步激活完成的证明；确切时序尚未证实。第 4 节的操作可行性假设在该靶标和两种来源条件下得到支持，“回调返回前完成激活”仍未独立验证。

I：优先继续验证 A3 的应用覆盖与组合输入，不转为正式架构。此次结果不证明 Chrome/Codex 自身的控件作为后台目标时均有效，不覆盖右键、SwiftUI、其他浏览器或窗口管理器 move/resize。

R（后续）：Chrome 与 Safari 作为后台目标，在停止/A3 对照中，普通按钮均由不执行变为一次操作，独立网页日志各记录一次 button_action。用户确认两浏览器输入框由不能直接输入变为首次点击后可输入；该结果未记录输入文字，证据等级为用户实测。右键在停止/A3 下均有效。Firefox、真实 ChatGPT 网页复制与组合输入仍待验证，详见运行记录。
