# 命中窗口与应用激活：公开 API 补充评估

日期：2026-10-14。平台 macOS 27 / SDK 27；Phase 1 研究补充，未确定最终架构，未追加正式功能。

证据标签：D 为 Apple 文档/SDK；R 为用户物理操作与日志；H 为待测；I 为推论。

## 已确认的实验边界

R：A3 仅写应用 AXFrontmost，对 Chrome 已前台时的另一个后台窗口跳过。同应用双窗口普通按钮在停止/A3 下均需第二次点击。

R：只观察原事件的三组对照（44/45、48/49、55/56），session tap 每组只收到两个正常 down/up，click count 1、2；对应激活点击与操作点击。网页直到第二个系统 down 后才收到首组 down/up/click，并用第二个 down 的时间戳，随后真实 up 又触发第二次操作。没有多出来的第三组系统输入；事件字段未变化，observe 未调用激活。

R：标题栏激活后快点按钮未连点（用户报告，未指定对照计数编号）；完全退出探针也能复现同按钮快点击。额外 click 的生成层已缩小到 session tap 之后，具体 AppKit/Chromium 分支未定位。原始证据：duplicate-input-layer-comparison.json。

I：下一步验证准确的命中窗口，而不是用应用已前台代替窗口准备就绪。不能添加全局去重、固定等待或把 click count 2 改成 1；这些会损害真正的双击，并掩盖首次点击丢失。

## 公开 API 与保证范围

| API | 已有依据 | 未保证的部分 |
| --- | --- | --- |
| [AXWindow](https://developer.apple.com/documentation/applicationservices/kaxwindowattribute) | D：从命中控件获得所属窗口的公开关联；值是窗口，不是 sheet/drawer | 命中、PID 与窗口关联仍要动态核查，不能用私有窗口 ID 函数补足 |
| [AXMain](https://developer.apple.com/documentation/applicationservices/kaxmainattribute) | D：窗口是否为应用 main 文档窗口；SDK 27 明确可写，要求窗口提供 | D：main 不一定有 key focus；设置 success 不等于真实事件进入控件 |
| [AXFocusedWindow](https://developer.apple.com/documentation/applicationservices/kaxfocusedwindowattribute) | D：应用当前 focused 窗口。SDK 27 NSAccessibilityProtocols.h:468-470 描述为 key window，服务端属性有 setter | 客户端跨进程可写性和实时完成没有普遍保证，必须 IsAttributeSettable 与实测 |
| [setAccessibilityFocusedWindow](https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/setaccessibilityfocusedwindow(_:)) | D：当前 AppKit 的公开服务端协议 setter，设置具有当前焦点的子窗口 | 不是任意全局工具直接取得外国 NSWindow 后调用的入口；不能据此保证所有客户端 AXFocusedWindow 可写 |
| [AXFocused](https://developer.apple.com/documentation/applicationservices/kaxfocusedattribute) | D：键盘焦点；focusable 元素可以设 true，不能设 false 取消焦点 | 不能假定所有窗口都可 focus；逐控件强行设置会改变真实点击语义，暂不作为核心 |
| [AXRaise](https://developer.apple.com/documentation/applicationservices/kaxraiseaction) | D：在应用允许的条件下把窗口带到尽可能前面；浮动窗口可能仍在上方 | 不保证 key focus 或该次鼠标分派时序；可能改变叠放，与窗口管理器需独立验证 |

SDK 证据：AXAttributeConstants.h:478-493（Focused）、805-818（Main）、1008（FocusedWindow）；NSAccessibilityProtocols.h:468-470（FocusedWindow 服务端 setter）。Apple 官方 JSON 快照与哈希保存在 window-focus-sources/source-index.json。

## 下一项最小验证

先利用已存在的 A2（AXMain 成功后普通应用激活），只改变前台条件：Chrome 应用自身已前台，另一个 Chrome 窗口后台。此前 A2 失败的数据是在 Codex 前台、Chrome/原生目标应用后台，不能代替这个条件的结果。

H：AXMain 在应用已活动时可能使其另一文档窗口具备接收首次点击的条件；官方 main 不等于 key 的限制仍适用。普通按钮恰好 +1、输入框一次点击后可输入才算操作证据，setter success/窗口前台不算。

保持 A3 与源代码不变，用停止/A2 分别记录同应用窗口的按钮、输入。若 A2 局部有效，再单独评估 AXMain + AXFrontmost 的组合 PoC；若无效，调查直接 focused-window 可写性及独立 AXRaise。各路线单独记录，不静默退回其他路径。

临时只读 Swift CLI 的 AXIsProcessTrusted 返回 false，未继续读取或设置外国应用，也未要求给额外工具授权。原 FirstClickProbe 的 AX 已授权且 observe tap 正常，继续复用既有实验应用。该 CLI 结果不能解释为 Chrome 不支持相关属性。

未知：focused-window 的实际可写覆盖、main 与 key 的应用差异、同应用 sheet/popover、多窗口叠放、yabai move/resize，以及将正确窗口状态调整完毕的事件时序。此报告不承诺统一 API 保证或最终架构。

## A2 同应用与跨应用条件的实际结果

R：用户以真实鼠标报告，在 Chrome 已前台、诊断页位于另一个 Chrome 后台窗口时，A2 一次点击按钮计数增加至 61；输入框一次点击后可以输入 abc。若先点击 Codex，随后一次点击同一诊断页的按钮或输入框，分别不增加、无法输入。输入内容未记录，输入结果采用用户反馈。

R：独立网页日志的 count=61、click_count=1，在原生 event_number=3105 的 up 后约 12.5 ms 收到。该 down 命中 Chrome PID944/窗口3053，前台来源也是944，探针后台；AXMain setter=0、普通 activation=true。down/up 及轻微 drag 的原事件指纹均未改动。其他邻近计数未冒充受控试次。

R：event_number=3112、3120、3127 从 Codex PID77884 命中同一 Chrome 窗口，AXMain setter 同样=0，普通 activation=false。它们支持跨应用请求失败这一上下文观测，未把每个事件强行分配给特定按钮/输入试次。证据保存于 runs/20261014-155656/chrome-same-app-a2.json。

I：A2 与 A3 的已测覆盖呈互补：A2 同应用条件有效、跨应用无效；A3 跨应用有效、同应用窗口跳过。普通 activation 返回值与此结果相符，但不能据此宣称 main 等于 key、API success 保证鼠标分派或已找到所有系统因果。

## A4：独立组合实验，先定问题再改探针

范围仍是 Phase 1 可丢弃 PoC。H：将 A2 中的普通 NSRunningApplication.activate 替换为已验证的应用 AXFrontmost 请求，保留前置命中窗口 AXMain，是否能同时覆盖两种前台条件？这是单一调用路径的替换，没有确定正式架构。

执行顺序明确为：公开屏幕命中与 PID/layer 校验 → AX 命中及 AXWindow 关联 → 确认可写并设置该窗口 AXMain=true → 仅在这一步成功后，对同一 PID 确认可写并设置 AXFrontmost=true → 返回同一个原 CGEvent。Chrome 已前台时也执行相同链，避免以 PID 已活动替代准确窗口。两个 AX 步骤分别记录错误；失败后放行原事件，不转入 A1/A2/A3、不重试、不补击。无需普通 activate、AXPress、AXRaise、控件焦点硬编码、私有窗口编号或应用白名单。

沿用原有无修饰键、普通窗口层的边界。每个 AX 对象的 25 ms messaging timeout 不构成整个回调上限；保留 A3 原有一次即时读回用于诊断，它不是完成屏障，也可能增加耗时。当前 PoC 会对已活动正常窗口的普通 down 执行窗口级链，开销、控件/标题栏差异及窗口管理器影响仍必须实测，不能作为生产策略。

D：本轮重新抓取 Apple 官方 AXMain、AXFrontmost 与 cooperative activation 文档，快照/哈希位于 activation-context-sources/a4-current-official。Main 文档明确允许无键盘焦点的 main 窗口；Frontmost 描述应用 active 状态，并未承诺同步 key-window 鼠标分派。普通 activation 是系统按上下文决定的请求。setter 页面特定编码 URL 返回404，错误保留在索引；公共 setter 及错误契约依据既有 SDK27 审查，不将网页获取失败当作 API 不存在。

最小验收：A4 开启且探针自身保持后台，先测试另一个 Chrome 窗口作为前台来源，再测试 Codex 作为前台来源；每种条件分别恢复后台状态后一次点击普通按钮（必须恰好 +1）和输入框（首次点击后直接输入）。关键输入由用户真实鼠标执行。若组合无效，记录失败后再评估顺序或其他公开窗口能力；不在同一试次静默叠加措施。右键/双击/拖动/复制、Safari 等回归随后进行，此轮成功也不构成 Phase 1 完整通过。

## A4 首组真实操作结果

R：用户按四项协议报告按钮68、输入成功、按钮69、输入成功。独立日志确认另一个 Chrome 窗口作为来源时计数67→68（event_number3173），Codex作为来源时68→69（3178）；每组只有一个系统 down/up、一个完整 DOM mousedown/up/click 与一次按钮操作。命中同一窗口3053，探针后台，两步setter成功，原事件字段未改动。网页操作接收分别在真实up后约8.7/7.9ms；这是HTTP接收间隔，不是完整交互延迟。

R：输入上下文3176与3180的来源PID分别944、77884，匹配用户操作顺序与输入区位置；首次点击后能输入为用户实测，未记录文字、精确插入点或用API焦点替代实际操作。

R：用户另确认70/71是主动按了两次的双击。原生3184/3185从Codex后台条件开始，down间隔约179.3ms，click count1/2原样保留；对应网页两组完整down/up/click、计数69→71，没有额外操作。此项只覆盖该普通按钮，不能代表文字双击选词或此前所有重复现象已解决。

R：用户补充右键“好像也没问题”。诊断页13条context_menu观测均可配对A4右键down/up，包含Codex→Chrome来源，事件字段未变。这些是探索性重复，没有预标注全部后台窗口条件；Chrome来源PID不能独立证明另一个窗口非key。菜单出现由用户观察与独立context事件支持，菜单选项业务执行尚未验证。基线右键原本有效，记录为保持能力。证据分别见chrome-a4-window-contexts.json与chrome-a4-right-observations.json。

I：在本机Chrome的已测子集里，A4同时覆盖了A2有效的同应用窗口条件和A3有效的跨应用条件。只有每种条件一个标注单击试次，不作统计可靠性或通用性承诺；正式架构仍不决定。下一轮优先回归原生拒绝靶标的单击、拖出取消及菜单选项，再验证真实复制、Safari与其他目标。

## 原生与Safari的A4追加边界

R：原生拒绝靶标从Codex来源的单击15→16；从后台拖出取消的两组保持原计数17/18，完整down/drag/up字段未变；随后前台恢复各+1。右键菜单和选项各2→3，选择菜单项时命中layer101并跳过激活，实际菜单操作仍执行。详见native-a4-regressions.json，不推断文字或文件拖动均正确。

R：Safari用户确认从Codex和另一Safari新窗口返回测试页的按钮、输入、右键均正常。独立页按钮0→1配对Codex来源3266；右键1/2配对Codex/Safari来源3282/3286。该页UUID只有一条button_action，输入与同应用按钮仍为用户反馈，不能补造独立试次记录。

R：Safari上下文出现6次AXFrontmost可写性查询-25204、2次即时读回-25204。查询错误没有Frontmost setter或重试；它不证明静态不可写。用户操作正常也不能使每次API错误自动变成成功。全记录safari-a4-window-contexts.json。

H：可写性查询或即时读回与目标应用忙、点击分派时序的关系尚未验证；同应用是否只需窗口步骤、哪些前台请求冗余，仍是后续可测问题。此轮不为消除错误修改路径，也不因此确定混合策略。真实网页复制停止/A4对照仍待执行。
