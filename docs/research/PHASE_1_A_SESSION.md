# Phase 1 A 运行记录

开始日期：2026-10-14；收尾日期：2026-10-15（Asia/Makassar）。状态：**本轮已停止，不再扩大测试范围。A4 已有原生、Chrome、Safari 及一组真实 ChatGPT 网页复制的局部证据，尚未证明全应用覆盖。Firefox 已清理，日志保留；不继续 VS Code 或其他新增目标。正式架构未定。**

当前结论见 [Phase 1 已有测试结论](PHASE_1_RESULTS.md)。以下按时间保留原始经过；其中“下一步”“待测”不再作为本轮执行任务。

用户已暂停 AutoRaise。只读检查未检出名为 AutoRaise/autoraise 的进程，yabai 和 skhd 仍在运行；不将该检查解释为其配置或兼容性已经验证。

用户确认待测桌面目标就是当前运行本对话的应用，按 `com.openai.codex` 记录。此前“桌面目标身份未确认”的前置空缺已解决；其他应用与 24 项矩阵未自动视为通过。

## 探针与靶标

- FirstClickProbe.app（本地文件 `poc/activation-preserve/build/FirstClickProbe.app`，未公开）：模式默认为停止；可选择基线、A1（仅应用激活）、A2（AXMain 成功后应用激活）、A3（仅 AXFrontmost）或 A4（AXMain 成功后 AXFrontmost）。
- FirstClickTarget.app（本地文件 `poc/activation-preserve/build/FirstClickTarget.app`，未公开）：独立原生进程，计数仅来自靶标真实事件与操作。
- [浏览器验证页面](http://127.0.0.1:9593/)：仅本机服务，包含普通按钮与代码复制的独立业务验证。
- 本次日志目录（本地文件 `poc/activation-preserve/runs/20261014-155656`，未公开）：引擎、靶标、浏览器证据分开保存。

每次代码复制前，必须在浏览器页面点击“准备复制试次”，写入不同的对照标记，再真实点击后台 Codex 的复制按钮一次，最后返回验证区粘贴。未准备的粘贴标为无效，避免旧剪贴板内容形成假阳性；运行日志不保存剪贴板原文。

返回 Chrome 的粘贴验证是结果读取步骤：先点击 Chrome 标题栏使其处于前台，再单击验证输入框，确认出现插入光标后按 Cmd+V。也可以在首次激活后再点一下输入框。这里不限制为一次点击；一次点击约束只针对后台 Codex 的复制按钮。不要把验证输入框未获得焦点、未收到 paste 事件当成复制失败。页面会显示匹配提示，不显示剪贴板原文。无需先清空输入框，paste 处理器会替换整个值。每轮必须核对结果中的试次编号与本轮准备编号一致；准备操作未清除上一轮匹配提示，不能只看“匹配”文字。

### 当前观测与证据边界

- 最新 A4 状态为 `ax_trusted=true`、`post_preflight=false`、`listen_preflight=false`、`tap_enabled=true`，模式 `axMainThenFrontmost`、PID22571；session revision 为 phase1-a4-main-frontmost。重新签名后曾因 AX=false 阻止启动，用户将原探针开关关闭再开启后启动成功。建立阶段的 down/up、setter 成功及原事件未变只证明运行条件；已标注实际操作结果见后文68/69，不以API返回值替代验收。preflight false 保留，不将它单独解释为已建立的 tap 没工作。状态文件 sequence 不随每次点击更新。
- 用户明确标注 trial 14 为基线、15 为 A1、16 为 A2。三次均有 `copy_trial_prepared(success=true)` 和 `paste_validation(valid_trial=true, clipboard_match=true)` 的独立浏览器记录。用户按一次真实鼠标点击后台复制按钮的步骤操作；引擎日志包含对应模式切换、Chrome 在前台时命中 Codex 的点击及事件字段未修改的记录。试次模式按用户标注记录，不把不同日志的单调时钟直接视为具有相同原点。
- 用户补充：准备、点击复制后，再点击 Codex 输入框或浏览器地址栏并粘贴，三种模式下均得到预期标记而非 CONTROL_PRECOPY。此项为用户实测反馈，支持剪贴板确实被复制操作更新；代理未读取通用剪贴板原文，也未单独验证这些输入框的后台焦点条件。
- 结论限于当前用户指定的 `com.openai.codex` 代码复制控件及实验条件：基线已经匹配，A1/A2 的匹配不能证明改善，更不能推断浏览器、其他原生应用、Electron 或通用 first-click 已解决。下一步建立默认拒绝首次点击靶标的完全停用探针基线，再与 A1/A2 比较。
- 早期 trial 1 有一次有效匹配，trial 2 只有准备记录。随后用户反馈三轮基线均匹配，并指出页面显示 trial 7。检查发现本机 HTTP 日志服务已退出，而已加载页面仍可在本地验证，导致期间结果未持久化；这部分保留为用户反馈，不能把日志缺失判为复制失败。服务已重新启动，GET 200、独立诊断 POST 204 且诊断记录保存成功；诊断不计为用户试次。trial 9（用户标注 A1）、10（用户标注 A2）均恢复了有效匹配日志。
- 相同试次完成验证后再次粘贴会产生 `valid_trial=false`；这些重复粘贴不另算成功试次。未由用户说明模式的额外试次不自动归类。
- Computer Use 的窗口配置操作不计入真实鼠标试次；`isTrusted` 本身也不作为物理输入来源的证明。

### 原生首次点击拒绝与接受对照

第一组以 Codex 为点击前的前台来源。用户用真实鼠标报告如下结果；独立靶标日志证实右侧累计操作计数为 1、2、3，左侧在这组中没有任何执行操作的 mouseDown/mouseUp。

| 条件 | 左侧拒绝 first mouse | 右侧接受 first mouse |
| --- | --- | --- |
| 完全停止探针 | 0 → 0 | 0 → 1 |
| A1，仅应用激活 | 0 → 0 | 1 → 2 |
| A2，AXMain 后应用激活 | 0 → 0 | 2 → 3 |

原生靶标与探针都记录 `DispatchTime.now().uptimeNanoseconds`，此处按同一宿主上的时间顺序将靶标记录归入已记录的模式区间。停止区间以探针的 stopped 记录为界，不要求停止时仍有探针鼠标日志。

**已观察到：**

- 左侧在每种条件下仍被询问 `acceptsFirstMouse` 并返回 false，未收到 `left_down` 或执行操作的 `left_up`。日志中额外的左侧尝试也均被拒绝，不把这些额外尝试冒充预定试次数。
- 右侧在三种条件下均返回 true，随后收到 `left_down` 和 `left_up(action_executed=true)`，累计操作数恰好升到 1、2、3。说明靶标及计数通道能区分实际操作。
- A1 点击目标时前台 PID 为当前 Codex，`activate(options:[])` 的返回值记录为 false；A2 中 `ax_hit=0`、`ax_main_set=0`，但同一激活调用的返回值仍为 false。字段 `activation_request_sent` 是现有 PoC 对 API Bool 返回值的命名，不是独立确认已经发生的激活。
- A1/A2 目标点击的事件字段检查均未变化。此项只证明探针未改动记录的字段，不能代替真实事件送达控件。
- 靶标在 `acceptsFirstMouse` 调用时 `application_active=true`，但停止探针基线也如此。该采样无法证明探针在放行事件之前完成了激活，不能据此诊断为“提前激活已成功但控件仍拒绝”。

**文档依据与尚未验证的解释：** Apple 的[协作激活说明](https://developer.apple.com/documentation/appkit/passing-control-from-one-app-to-another-with-cooperative-activation)明确只有活动应用能通过 yield 影响激活上下文，系统根据上下文决定请求是否获准；[activate(from:options:)](https://developer.apple.com/documentation/appkit/nsrunningapplication/activate(from:options:))也不保证激活。SDK 27 进一步明确不能假定激活立即完成。现有 A1/A2 不调用 yield；不能将后台探针的普通请求当成完成了协作激活。官方文档未给出本次 false 的唯一原因，后台请求者条件与事件处理时序仍是待验证假设。

**结论：** 当前 A1/A2 组合在本机、此靶标、Codex 为前台来源的条件下没有解决首次点击。该结果否定了当前 PoC 达到通用目标的假设，不等同于证明所有公开 API 或不重放路线不可能。暂不进入 Phase 2 或正式开发。

### A1 前台来源诊断：FirstClickProbe → 原生拒绝靶标

用户按最小诊断步骤操作，在 A1 下使 FirstClickProbe 自身处于前台，然后直接单击左侧一次，报告 **0 → 1**。此轮没有修改代码、事件字段或靶标的 first-mouse 策略。

- 探针记录 sequence 372、event_number 2036，前台来源 PID 45104（探针本身），命中 PID 45166（独立靶标），模式为 activateApp。
- 同一个 `activate(options:[])` 调用此次返回 true，记录的原事件字段保持不变。
- 独立靶标在相邻同源时间记录 `left_down(target=reject, window_key=true)` 和 `left_up(action_executed=true, count=1)`；此轮未新增 `accepts_first_mouse` 记录。
- 原生靶标真正执行了一次，不只是窗口获得焦点。该对照支持前台来源影响本次激活请求与事件送达的解释；一次成功不能承诺这种时序在其他应用或每次点击都成立。

**修订结论：** 已观察到公开 A1 API 在请求者自身处于前台的受控条件下，让原先拒绝首次点击的控件执行了真实事件。此前 Codex 为前台来源时的失败仍然成立。当前证据不能支持一个在任意第三方应用前台、探针后台运行的通用方案，也不能将成功解释为必须先点击工具的最终产品设计。

下一项最小对照保持 A1 及同一控件，分别从 Chrome 前台、FirstClickProbe 前台直接单击左侧一次。它验证此前失败是否仅限 Codex 来源，并对探针前台成功作一次复核；不进入正式功能开发。

### A3 后台探针：Chrome / Codex → 原生拒绝靶标

先完成 [公开 API 补充调研](ACTIVATION_CONTEXT_ADDENDUM.md)，再追加独立 A3。用户重新授权辅助功能并用真实鼠标操作，报告从 Chrome 和 Codex 切来后，原先无效的左侧计数均加一。

| 点击前前台来源 | 探针是否活动 | 事件编号 | 拒绝靶标实际操作 |
| --- | --- | --- | --- |
| Chrome，PID 944 | false | 2149 | 4 → 5；完整 left_down / left_up，action_executed=true |
| Codex，PID 15809 | false | 2160 | 6 → 7；完整 left_down / left_up，action_executed=true |

两次均命中独立靶标 PID 68927、窗口 2676，click count 为 1、无键盘修饰键；原 down/up 字段保持不变。此靶标是重新启动后的进程，不能把其累计计数与此前 PID 45166 的计数连续比较。配对证据冻结在 native-a3-background-sources.json（本地文件 `poc/activation-preserve/runs/20261014-155656/native-a3-background-sources.json`，未公开），按同宿主 Dispatch uptime 将原事件和独立操作证据关联。

两次 AXFrontmost 均可写、设置返回成功；即时读回仍为 false，写入后的 NSWorkspace 前台 PID 仍是原来源。实际操作却已经执行，因此不把即时读值当作同步激活屏障，也不声称已证实激活完成的精确时刻。A3 未调用 AXPress、AXMain、普通 activate 或事件重投。

**局部结论：** 公共 AXFrontmost 路线在已测两种第三方前台来源下，能让后台探针保留原事件并使拒绝控件执行。Chrome/Codex 此处是点击前的来源应用，不是被测控件所在应用。浏览器作为目标、其他原生控件、右键、双击、拖动、修饰键及窗口管理操作仍待测；继续 Phase 1。

用户此前换显示器复测后报告“没有关系”，记录为用户未观察到影响；没有独立多屏几何矩阵，不能据此排除全部多屏条件。保存证据时 yabai/skhd 仍在运行、未检出 AutoRaise，但未执行 move/resize 回归。

### Chrome 作为后台目标：停止与 A3

用户按同一页面、每项先使 Codex 前台再真实点击一次的协议反馈：

| 操作 | 完全停止探针 | A3 | 证据 |
| --- | --- | --- | --- |
| 普通按钮 | 不增加 | 恰好 +1 | 页面重新加载后的独立日志只有一次 button_action，count=1、click_count=1；模式归属由用户反馈和探针切换/输入顺序共同支持 |
| 普通输入框 | 首次点击后无法直接输入 abc | 首次点击后能直接输入 abc | 用户实测；页面不记录输入内容或焦点，未独立记录文字 |
| 右键上下文区域 | 计数 +1、菜单出现 | 计数 +1、菜单出现 | 独立 context_menu 计数 1、2、3；额外早期菜单事件不另算受控试次，菜单选项执行尚未测 |

目标 Chrome 155.0.8059.79，PID 944；A3 试次前台来源为当前 Codex PID 77884，探针仍在后台。事件 2286（按钮）、2288（输入区域）、2290（右键区域）按用户操作顺序记录，down/up 字段均未改动。HTTP 日志单调时钟不与 Dispatch uptime 直接配对。原始记录与证据边界保存于 chrome-a3-first-click.json（本地文件 `poc/activation-preserve/runs/20261014-155656/chrome-a3-first-click.json`，未公开）。

按钮事件中 AXFrontmost setter 成功，但诊断 readback 返回 -25204；回调工作耗时记录为 34,856,750 ns（约 34.9 ms），不含后续日志成本，不是端到端延迟。操作实际执行，说明读回失败不能单独视为操作失败；该诊断开销保留供后续性能验证，不在本轮改变核心路径。

**局部结论：** A3 的改善已扩展到 Chrome 作为目标的普通按钮和输入框。右键基线已经有效，A3 下也有效，不计为新增改善。Safari/Firefox、真实 ChatGPT 网页复制、双击/拖动/修饰键及窗口管理回归仍未验证。

### Safari 作为后台目标：停止与 A3

用户报告“跟 Chrome 一致”，对应同一三项协议：停止时普通按钮不执行、输入框无法直接输入；A3 下按钮 +1、输入框可直接输入；右键在两种状态下均有效。

Safari 27.0.1（22625.1.29.11.28）、PID 84057，前台来源为 Codex PID 77884。Safari 页面加载后独立记录一次 button_action(count=1, click_count=1)，两次 context_menu(count=1,2)。A3 输入序列 2320、2322、2324 命中 Safari，探针在后台，down/up 字段未变。模式归属由用户反馈与事件顺序支持，不直接比较 HTTP receive 时钟和 Dispatch uptime；文字及焦点未记录，输入结果为用户实测。

按钮事件 2320 的 AXFrontmost setter 成功，readback 返回 -25204，callback_work_ns=40,849,709（约 40.8 ms，排除后续日志）。保留为诊断成本观察，不视为完整延迟预算。独立记录见 safari-a3-first-click.json（本地文件 `poc/activation-preserve/runs/20261014-155656/safari-a3-first-click.json`，未公开）。

**局部结论：** A3 对后台普通按钮及输入框的改善已在 Chrome 和 Safari 分别观察到；右键基线均已有效。Firefox、真实 ChatGPT 网页复制、其他框架、组合鼠标语义及完整工具兼容仍待测，继续 Phase 1。

### Codex 输入、原生双击与拖出取消

用户按停止/A3 对照反馈：当前 Codex 输入框两种状态下均能输入 fc。这是用户实测，未读取或保存输入内容；基线已有效，不记为 A3 改善，也不从这一输入条件推断所有控件。

在 A3 下，独立拒绝靶标日志及探针同源时钟配对证实：

- 双击：event 2351/2352 的 target down/up click count 分别为 1、2，计数 8 → 9 → 10；首次 down 前台来源为第三方应用，第二次是同一靶标前台。两次原事件字段均未变。
- 拖出取消：event 2355 从 Chrome 前台命中拒绝靶标，收到完整 down/drag/up，102 条输入事件字段均未变；靶标 had_down=true、dragged=true、inside=false、action_executed=false，计数保持 10。
- 后续单击恢复：event 2356 收到 down/up 并执行一次，计数 10 → 11。此时靶标已经前台，证明取消后控件可继续操作，不单独作为后台首次点击试次。

后续日志还观察到其他重复取消、单击及双击；保留为观测，不增加预定受控试次次数。原始配对与边界见 native-a3-gesture-checks.json（本地文件 `poc/activation-preserve/runs/20261014-155656/native-a3-gesture-checks.json`，未公开）。此结果只覆盖该 NSView 的双击计数及拖出取消，不证明文字选择、文件拖动或其他应用全部手势正确。

下一项是原生右键菜单选项与 ChatGPT 网页代码复制。Chrome 已准备新的 ChatGPT 测试页及单行提示草稿；准备阶段一次多行 typeText 将首行意外提交，已停止发送并用 setValue 整理剩余草稿。该网页尚无有效目标代码块，所有准备动作均为 Computer Use，不计真实鼠标试次；后续发送提示和关键点击交由用户操作。此前回复显示无法加载，不能把目标准备问题归因于 A3。

### 原生右键菜单与实际 ChatGPT 网页代码复制

用户报告原生左侧右键在停止/A3 下，“右键菜单打开”和“菜单选项执行”均各 +1。独立靶标日志分别记录两组 right_menu_open / menu_action，累计计数 1、2；以 Dispatch uptime 归入停止与 A3 模式区间。停止时靶标 application_active=false、window_key=false，菜单选项仍执行；不将 A3 的窗口激活当作右键改善。

用户在真实 ChatGPT 网页生成预期标记的代码块，并使用页面自带“复制代码”按钮。代理后来只读 AX 快照确认代码块内容及该按钮存在，没有修改网页业务或读通用剪贴板。用户操作与独立粘贴验证如下：

| 两页面布局（用户确认） | 停止 | A3 |
| --- | --- | --- |
| 同一个 Chrome 窗口 | trial 10：有效不匹配 | trial 11：有效匹配 |
| 两个不同 Chrome 窗口 | trial 30：有效不匹配 | trial 31：有效匹配 |

四个试次均有且只有一条 success=true 的准备记录和一条 valid_trial=true 的验证记录，模式及布局按用户反馈归属。同编号旧试次用最近 page_loaded 分段排除，其他未归类、重复准备与无效粘贴不计入结果。一次点击约束针对后台网页代码复制按钮，返回验证区的额外聚焦点击不混入这个计数。非匹配表示未获得预期标记；没有读取原文来区分对照残留或其他内容。

用户补充，两页面位于不同 Chrome 窗口时，验证框在停止和 A3 下均需要点击两次才能输入，但复制结果仍分别为不匹配与匹配。当前 A3 对命中 PID 已是 frontmost 的事件记录 app_already_frontmost 并跳过请求（Probe.swift:287）。路由记录中可见 event 2626 从 Codex 激活 Chrome 窗口 1439，随后 event 2627/2628 命中同 PID 的窗口 2985 被跳过；这些输入未与验证框坐标独立绑定，作为相符观测，不视为唯一原因证明。

**结论与下一步：** 已观察到跨应用后台真实网页复制的改善，且结果不依赖测试页与网页是否同一 Chrome 窗口。Chrome 自身前台、另一个 Chrome 窗口后台的处理仍是明确覆盖空缺；先做独立普通按钮/输入对照，再研究窗口级公开 API，尚不更改 A3 或确定正式架构。配对记录与边界见 web-copy-and-native-menu-a3.json（本地文件 `poc/activation-preserve/runs/20261014-155656/web-copy-and-native-menu-a3.json`，未公开）。

### 同应用后台窗口失败与偶发双操作

用户完成独立 Chrome 两窗口按钮对照：停止和 A3 均需要第二次点击才 +1。此前验证输入框需两次点击聚焦的现象得到独立按钮反馈支持；当前 A3 没有解决同应用非 key 窗口。

用户另确认只按一次外接鼠标，按钮计数有时连续 +2，指定 A3 下的 74/75、81/82 及停止下的 85/86。独立网页日志三组分别是 click_count 1、2，间隔约 98.1、101.6、94.3 ms。时钟校准后，74/81 的第一次 DOM 操作靠近下一组原生 down，75/82 靠近对应 up；85/86 位于 stopped 区间，tap 已移除。不能只凭停止结果就归因于鼠标或排除 A3 的残留影响。

原始证据及边界保存于 same-app-window-and-duplicate-actions.json（本地文件 `poc/activation-preserve/runs/20261014-155656/same-app-window-and-duplicate-actions.json`，未公开）。无 tap_disabled 记录；当前代码没有重放路径，81/82 关联原生 down 均跳过激活，但浏览器 mousedown/up 数据尚缺。**根因未确认，未实现去重或其他行为修复。**

先保存 [诊断方案](DUPLICATE_CLICK_DIAGNOSTIC.md)，再准备独立 [连点诊断页](http://127.0.0.1:9594/)。保留原 onclick 计数，追加 pointer/mouse/focus 事件记录，未阻止或合成输入；不记录键盘及原文。新页会话 UUID 区分加载，独立 HTTP 服务写入原生 uptime，避免不同单调时钟未校准归属。事件显示固定高度，避免日志文字使按钮在 down/up 间移动。

诊断服务 GET 200、纯协议诊断 POST 204，确认原文额外字段被过滤；这些不是物理鼠标试次。探针在 stopped、tap_enabled=false 状态后，按已核实 PID/可执行路径退出并以 ESRCH 确认进程不再存在。新页已加载、计数为 0；用户下一轮实际操作尚未执行。当前诊断运行目录由 runs/20261014-155656/duplicate-diagnostic-active.txt 指向，原 9593 服务及历史日志保留。

用户随后确认：第一次激活窗口也点击同一个按钮；短间隔会出现 28/29、33/34，慢点击 30 不重复。独立日志显示异常首组 down/up/click 与下一组 down 使用同一时间戳；两次 click 触发两次原 onclick，不是计数器把单个 click 加两次。此轮探针全程退出，具体 Chromium/AppKit/上游生成者仍未确认。证据与源码核查边界见 [诊断报告](DUPLICATE_CLICK_DIAGNOSTIC.md)。

保存上述完全退出对照后，代理重新启动原探针并启用 observe；最新状态 tap_enabled=true、mode=observe，A3 未启用。仅为下一轮关联 session 原事件与诊断页 DOM 序列，没有修改或模拟关键试次输入。下一轮比较同按钮激活的快点击与标题栏激活的快点击，不添加延迟、去重或改写 click count。

Observe 对照追加：44/45、48/49、55/56 每组只有两个原生 down/up，click count 1/2；没有多出来的第三组系统输入。第一组 DOM click 在第二个系统 down 后被生成，再在真实 up 时执行第二组，额外生成层位于 session tap 之后。标题栏激活快点未连点为用户反馈。具体 Chromium/AppKit 分支未定位；不再把现象简单称为探针重放或鼠标抖动。层间配对与限制见 duplicate-input-layer-comparison.json（本地文件 `poc/activation-preserve/runs/20261014-155656/duplicate-input-layer-comparison.json`，未公开）。

已保存 [公开窗口级 API 补充评估](WINDOW_FOCUS_ADDENDUM.md)，未修改 Probe 源码。下一项最小条件实验使用现有 A2，测试 Chrome 已活动但命中另一个后台窗口的真实首次按钮和输入操作；此前 A2 的跨应用失败不自动代表此条件。

报告保存后通过 Computer Use 选择 A2、启动并读取状态：mode=axMainThenActivate、tap_enabled=true、ax_trusted=true。这些只是设置操作，不计物理鼠标试次；此同应用条件下的按钮及输入结果仍为 NOT_RUN。源码及二进制未重建，未要求额外工具权限。

### A2：Chrome 已活动的另一后台窗口与 Codex 来源对照

用户确认 Chrome 已前台时，A2 使诊断页按钮一次增加到61，输入框一次点击后可输入abc；先点击Codex后，同页按钮不增加、输入失败。独立按钮61和 event_number3105 的 down/up 配对，Main setter0、普通 activation=true；从Codex命中同页的上下文记录 Main setter0、activation=false。输入为用户实测，未保存文本。证据与归属边界见 chrome-same-app-a2.json。

已先更新 WINDOW_FOCUS_ADDENDUM.md 中的 A4 假设和最小协议，保存 source-before-a4、probe-app-before-a4.zip、probe-before-a4.json，再准备独立 AXMain→AXFrontmost 变体。此时 A2 在运行；A4 尚未构建、尚未运行，最终架构未定。

### A4 构建和启动条件

只追加独立 A4 模式，保留所有对照路径。先设置命中窗口 Main，成功后设置同一应用 Frontmost；不以目标 PID 已前台跳过窗口步骤、不调用普通 activate。两步分别记日志，失败没有回退、重试或事件重放。

候选 Probe 构建成功，最低27/SDK27，版本0.0.3/build3，codesign strict 通过；现有真实点击标志测试9/9，链接符号未发现重放/AX动作/所列私有窗口入口。独立 Target 未重建、原计数和全部历史日志保留。构建证据 probe-a4-build.json 与启动证据 probe-a4-runtime-setup.json 分开保存。

通过 Computer Use 停止旧 A2，退出并核验原进程消失后替换已留档应用。系统对重新签名的进程返回 AX=false；用户重新启用同一探针的既有开关后，控制窗口及状态显示 A4 运行。setup 不作为物理首次点击；下一轮要求每项重新将诊断窗置于指定来源的后台，按钮只点一次并记录 +0/+1/+2，输入先清空旧值，再恢复后台条件，首次点击后键入abc。

### A4：Chrome 两种前台来源、主动双击与右键

用户按四项真实输入协议报告：另一个Chrome窗口→按钮68、输入成功；Codex→按钮69、输入成功。独立按钮计数为67→68和68→69，分别配对event_number3173/3178。两次各一组系统down/up、一次DOMclick和一次button_action；探针在后台，命中Chrome窗口3053，两步setter成功，原事件字段未变。输入上下文3176/3180吻合来源、顺序和位置，输入结果采用用户报告，未保存文字。每种条件只有一个标注单击试次，不作可靠性统计。

70/71由用户确认是主动按两次的双击，配对3184/3185，从Codex前台来源开始。click state1/2保留，down间隔约179.3ms，对应两次网页操作，计数69→71。只证明该普通按钮条件，没有将它当此前重复操作问题全面修复。

用户另报告右键好像正常。13条独立context_menu观测可配对A4右键down/up，包含Codex→Chrome；全部字段未变。它们为探索性重复，未给每次赋予未标注的同应用后台窗口条件。菜单选项执行未验证，基线右键已有效。完整边界保存在chrome-a4-window-contexts.json及chrome-a4-right-observations.json。

下一轮维持现有A4源码与模式，回归FirstClickTarget左侧拒绝first mouse控件：Codex前台来源的单击、按住拖出取消及随后恢复、右键菜单打开与“记录菜单操作”选项执行。不通过Computer Use代替关键物理输入，不重新构建或调整行为。

### A4：原生拒绝靶标回归

用户报告三项：单击+1；拖出计数不变、随后正常单击+1；右键菜单打开和选项执行均+1。独立靶标日志确认：

- Codex前台来源的event_number3241：左计数15→16，收到原down/up后action_executed=true。3243重复单击16→17保留为追加观测，不增加预标注试次。
- 从Codex来源拖出的3245：计数保持17，had_down=true、dragged=true、inside=false、action_executed=false，73条down/drag/up字段未变。其后另有重复取消3246，恢复单击3247为17→18。
- 另一Codex来源取消3249保持18，71条原事件字段未变；随后3250为18→19。两次恢复均发生在靶标已前台，不冒充新的后台首次单击。
- 右键3252从Codex命中靶标，菜单打开2→3；菜单项选择3253命中同进程layer101，按已有边界跳过激活，独立菜单操作2→3。相关原事件字段未变，没有点穿菜单的这次操作证据。

完整配对及额外重复边界保存于native-a4-regressions.json。自有NSView拖出结果不代表文字/对象/文件拖动均正确；负x坐标成功也不升级为全缩放多显示器覆盖。源码、模式和靶标进程未改动，tap_disabled未出现。

### A4：Safari两种来源及API失败观测

通过Computer Use在Safari打开9594诊断页，只作为准备；页面UUID为a93f4a75-a729-430f-b67a-532a97779967。用户确认普通按钮+1、首次点击输入、右键菜单三项均正常，并补充从Codex和另一个Safari新窗口切入测试页两种条件均测试。

Safari PID84057、诊断窗口3337、另一个窗口3356。独立按钮0→1配对3266，Codex前台来源，完整down/up/click与一次button_action；右键context count1/2分别配对3282/3286，来源Codex/Safari。原事件字段未变。输入及同应用按钮结果目前以用户反馈为证据：该页面UUID只有一条button_action，不能把缺失独立同应用按钮日志当成新增成功试次，也不直接判为失败；另一个counter mousedown没有配对click的DOM记录保留为观测。

Safari观测里6次AXFrontmost可写性查询返回-25204、2次即时读回返回-25204。查询失败时没有设置Frontmost，也没有重试/回退；窗口Main步骤的成功不能保证所有操作。日志中的frontmost_not_writable标签同时覆盖查询错误，不等于已证实Safari静态不支持或不可写。用户仍报告操作正常，不能反推每次错误对应一次成功业务操作。后续要解释错误与事件阻塞/时序的关系，不能仅为隐藏错误改动引擎。完整记录safari-a4-window-contexts.json。

### 下一项真实网页复制准备

现有ChatGPT用户标签页标题已变为“macOS 点击穿透实现”，只读检查其当前渲染代码未找到独立预期标记，不发送新消息或修改研究会话。另开ChatGPT标签846781750，填写未发送的单行提示，要求只输出FIRST_CLICK_PROBE_2026_10_14代码块；草稿截图a4-web-copy-draft.jpg、准备状态a4-web-copy-preparation.json保存。这不是已生成代码块或已通过复制。

下一轮用Safari9594的准备/粘贴作为独立见证，真实复制目标为Chrome内实际ChatGPT网页代码块的“复制代码”。先用户发送草稿并等目标生成，再做停止/A4各一轮：切换模式后在Safari重新准备对照，物理单击后台网页复制一次，回Safari粘贴，记录本轮试次号与有效匹配。验证框无需清空，其paste处理替换值；每轮仍必须重新准备。代理不读原剪贴板、不使用本地“复制上述标记”替代真实网页控件。

### 2026-10-15：网页复制试次1，匹配有效，首次点击条件待确认

日期按用户时区Asia/Makassar记录。用户反馈“没问题”“试次1：匹配”。9594独立日志的新页面UUID为ff5ffe92-893a-4f3a-9491-b8ce787f8e12，与前日各试次1隔离。只有一条trial1准备记录且success=true；只有一条验证记录，valid_trial=true、clipboard_match=true。未读通用剪贴板原文，准备到粘贴区间没有本地copy_click/copy_api记录。

模式标记及区间内输入明确为axMainThenFrontmost，原PID22571仍在运行；没有stopped切换，不能按计划顺序把本次推定为停止对照。准备来自Safari新窗口3541，随后Chrome窗口1439出现两次down：3333时前台来源Safari，3334时Chrome已经前台。两者原事件字段未改动。坐标不能独立证明对应控件，代理已询问用户是否先点击Chrome标签/标题栏，再复制，尚未把有效粘贴匹配记为后台首次点击通过。

返回Safari标题栏3335的AXWindow关联返回-25205，原事件放行、没有回退；下一次验证区3336正常进行窗口/应用步骤并发生有效粘贴。保留此命中边界，不把读结果时的额外聚焦点击混入复制按钮次数。证据保存于web-copy-a4-trial1-20261015.json，单击条件等待用户确认，停止对照仍未记录。前日草稿标签846781750当前已无法取得，不假定它仍是本次目标。

用户随后明确确认“直接点了后台的复制按钮，随后还有其他点击”。据此把3333对应为一次后台真实网页复制：Safari前台来源，Chrome PID944/窗口1439后台，探针自身后台，两步setter成功；同sequence只有一个down/up且字段未改动。3334为用户所述后续其他点击，不擅自当第二次复制。试次1现记录为A4后台首次复制有效匹配，控件身份依用户明确反馈与操作顺序，独立准备/粘贴日志证明得到预期内容；停止比较仍待完成。资格更新及边界追加至原证据JSON。

已通过Computer Use点击现有Probe的“停止”，界面显示已停止；原进程和模式选择A4保留，tap移除，不退出/重建应用。下一项停止对照仍复用当前Safari页，重新准备后一次点击后台网页复制，再返回粘贴，预计本页编号为2，以实际编号为准。模式切换设置不计物理试次。

### 2026-10-15：停止试次3不匹配，与A4试次1形成局部对照

用户反馈“试次3：不匹配”。同一页UUID ff5ffe92-893a-4f3a-9491-b8ce787f8e12中，trial3只有一条success=true准备和一条valid_trial=true验证，clipboard_match=false。最近模式标记为stopped，且早于准备；整个试次区间没有模式切换，状态tap_enabled=false、原进程22571仍存在。停用tap后没有本探针鼠标记录，关键复制目标及单次物理操作按用户所循协议记录，不补造系统输入配对。

trial1在A4下有效匹配，trial3在停止下有效不匹配，支持本场景的改善；只是一组标注对照，不作统计可靠性或通用性承诺。不匹配意味着未得到预期标记，未读取原文区分对照残留或其他内容。另有trial2有效匹配发生在停止标记之前，属于A4日志观测，用户未标注其关键点击过程，不另算受控试次。完整记录为web-copy-stopped-trial3-20261015.json及web-copy-a4-comparison-20261015.json；原停止准备NOT_RUN文件作为历史设置证据保留。

对照保存后，通过Computer Use启动已选A4，恢复同一进程；不重建或修改探针源码。下一项补Firefox与实际Electron目标。常见Firefox安装路径未找到，既有Firefox用户配置根目录也不存在；已从Mozilla官方latest下载入口取得158.0安装包，原文件和SHA256保存在browser-target-preparation，待签名/Gatekeeper与启动准备。VS Code 1.140.0、com.microsoft.VSCode已安装且包含Electron Framework.framework，框架身份确认但物理试次尚未开始；当前ChatGPT.app未见该框架，不能凭名称或外观把它充作已确认Electron靶标。

只读yabai配置为mouse_modifier=fn、mouse_action1=move、mouse_action2=resize、focus_follows_mouse=disabled、mouse_follows_focus=off。yabai/skhd继续运行，未检出AutoRaise。未改配置，也未因此宣称Fn拖动/缩放与快捷键回归已通过。目标身份、版本及配置快照见browser-target-preparation/target-inventory-20261015.json。

## 2026-10-15：停止实验、清理 Firefox 并收敛结论

用户要求先清理本次安装的 Firefox 和相关残留，保留实验日志，不再扩大测试。已停止探针，运行状态为 `mode=stopped`、`tap_enabled=false`。整理过程未新增物理试次、修改探针行为或重新构建应用。

本次 Firefox 来自 Mozilla 官方 DMG，未使用 Homebrew，未放入 `/Applications`；已启动到欢迎页，但未接受继续使用条款，未完成物理试次。应用、DMG、首次启动创建的 `Application Support/Firefox`、`Caches/Firefox`、`Caches/Mozilla` 及 `org.mozilla.firefox.plist` 共 6 项已移入用户废纸篓，空运行／挂载目录移除。下载、签名／Gatekeeper 校验和所有实验日志保留；45 份原有日志及记录 SHA-256 未变化。清理清单见 firefox-cleanup-20261015.json（本地文件 `poc/activation-preserve/runs/20261014-155656/browser-target-preparation/firefox-cleanup-20261015.json`，未公开）。废纸篓未清空，未改动系统日志或共享数据库。

A4 保留为现有证据最充分的候选，不将未完成矩阵视为通过；本轮不继续 Firefox、VS Code、SwiftUI 或其他新增／重复试次，不进入正式功能开发。

## 已完成的准备验证

| 项目 | 结果 | 证据边界 |
| --- | --- | --- |
| Swift 6 构建，目标 arm64/macOS 27 | 两个 app 构建成功 | 不证明运行时 first-click 成功 |
| 本地 ad-hoc 签名验证 | 两个 app 校验通过 | 仅本地实验，未公证/分发 |
| 点击修饰标志行为测试 | 9/9 通过 | 捕捉系统 non-coalesced 标志被误当键盘修饰键的错误；已先观察 8/9 的预期失败，再修正通过 |
| 链接符号静态审查 | 未发现 CGEventPost、CGEventCreateMouseEvent、AXUIElementPerformAction 或所列私有窗口操作依赖 | 静态检查配合源码，只支持本探针未实现重放/AXPress 路径；不证明最终通用性 |
| 浏览器 HTTP 与原文过滤检查 | 通过 | 在隔离临时目录自测；不是实际鼠标点击结果 |
| 应用启动 | 两个控制/靶标进程启动，浏览器记录 page_loaded | 只证明启动；业务用例仍未测 |
| 初始权限状态 | AX、Listen、Post preflight 均 false；tap 未启用 | 系统 TCC 前置条件，已打开辅助功能入口交给用户启用 |
| 用户授权后重新启动 | AX、Listen、Post preflight 均 true，observe tap 已启用 | 仅证明探针运行条件；首次点击仍需受控试次 |

## 运行时试次

| 用例 | 基线 | A1 | A2 | A3 |
| --- | --- | --- | --- | --- |
| 当前 Codex 后台代码复制 | trial 14 有效匹配；基线为 observe | trial 15 有效匹配 | trial 16 有效匹配 | NOT_RUN：未归类后续复制试次 |
| 当前 Codex 输入框 | 完全停止：用户确认能输入 fc | NOT_RUN | NOT_RUN | 用户确认能输入 fc；基线已有效 |
| ChatGPT 网页代码复制，Chrome | 完全停止：同窗 trial 10、不同比窗 trial 30，均有效不匹配 | NOT_RUN | NOT_RUN | 同窗 trial 11、不同比窗 trial 31，均有效匹配 |
| 原生拒绝 first mouse 靶标左键操作 | 完全停止探针：0 → 0 | Codex 前台：0 → 0；探针前台：0 → 1 | Codex 前台：0 → 0 | Chrome 来源：4 → 5；Codex 来源：6 → 7；探针均在后台 |
| 原生接受 first mouse 正对照 | 完全停止探针：0 → 1 | 1 → 2 | 2 → 3 | 观察到接受控件操作，未建立独立预定试次 |
| 原生右键菜单及菜单选项 | 完全停止：打开及选项各执行一次 | NOT_RUN | NOT_RUN | 打开及选项各执行一次；基线已有效 |
| 原生拒绝靶标双击 | NOT_RUN | NOT_RUN | NOT_RUN | 8 → 10；click count 1、2 保留 |
| 原生拒绝靶标拖出取消及恢复 | NOT_RUN | NOT_RUN | NOT_RUN | 拖出保持 10；随后单击 10 → 11 |
| Chrome 普通后台按钮及输入框 | 完全停止：按钮不执行、无法直接输入 | NOT_RUN | NOT_RUN | 按钮执行一次（独立日志）；输入框直接输入（用户实测） |
| Chrome 后台右键 | 完全停止：菜单出现、计数增加 | NOT_RUN | NOT_RUN | 菜单出现、计数增加；选项执行未测 |
| Safari 普通后台按钮及输入框 | 完全停止：按钮不执行、无法直接输入 | NOT_RUN | NOT_RUN | 按钮执行一次（独立日志）；输入框直接输入（用户实测） |
| Safari 后台右键 | 完全停止：菜单出现、计数增加 | NOT_RUN | NOT_RUN | 菜单出现、计数增加；选项执行未测 |
| yabai 同时运行下的实际操作 | 当前复制试次发生时未主动停用 yabai；通用兼容性待测 | 同左 | 同左 | 原生左键试次时仍运行；move/resize 待测 |

窗口获得焦点、activate 返回值、事件字段未修改均为中间观测。只有独立靶标计数或有效复制试次的匹配结果，结合真实输入条件，才能形成该场景的实验结论。

当前 A1/A2 只干预无键盘修饰键、普通窗口层的 down；带修饰键与其他窗口层原样放行，不声称已经覆盖。A2 的 AX 步骤失败不会默默改为 A1。事件观察的 `callback_work_ns` 记录处理工作耗时，不包含随后日志序列化的全部成本，不能直接当完整端到端延迟。

未开始 Phase 2 最终架构决策或 Phase 3 正式开发。
