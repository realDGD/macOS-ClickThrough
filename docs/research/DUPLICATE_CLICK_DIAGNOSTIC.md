# 同应用窗口与偶发双操作：诊断入口

日期：2026-10-14。状态：根因未确认，尚未修改点击行为。

用户物理鼠标反馈：两个 Chrome 窗口之间，停止和 A3 都要第二次点击才执行普通按钮；另外只按一次外接鼠标，页面计数有时连续 +2（74/75、81/82、85/86）。同应用窗口空缺成立；双操作是独立未解决问题。

## 已确认的证据

- 浏览器计数三组分别记录 click detail 1、2，网页时间间隔约 98.1、101.6、94.3 ms；每条是独立 button_action，不是代理按文字猜测。
- 对正在运行的本地 HTTP 服务做三次纯时钟诊断 POST，将其 Python monotonic 接收时钟与 mach_absolute_time 转换后的宿主 uptime 校准；本次 offset 区间不确定度约 0.77 ms。诊断 POST 不计鼠标试次。校准仅适用于该 HTTP 服务进程；重启后重做。
- 74/81 的第一次 DOM 操作均靠近下一组原生 down；75/82 的第二次靠近对应 up。前一组 up 与第一次 DOM 操作隔了约数百毫秒。现有日志没有浏览器 mousedown/up 序列，不能确定延迟/补偿发生在哪一层。
- 85/86 对应探针 stopped 区间，tap 移除；运行时当前 tap_enabled=false。停止出现双操作不能直接证明是硬件，也不能排除先前激活的残留状态。
- 当前探针不创建或重投鼠标事件。A3 只写 AXFrontmost；81/82 对应两次 down 都因 app_already_frontmost 跳过。没有 tap_disabled 记录。未观察到事件字段被改动。

原始快照：runs/20261014-155656/same-app-window-and-duplicate-actions.json；时钟校准：double-click-clock-calibration.json。保留停止/A3 反馈，不将未分类额外点击冒充受控试次。

## 尚未验证的假设

可能涉及浏览器窗口激活时的 press/release 配对或残留状态，也可能是上游输入/其他软件。系统 tap 和 DOM isTrusted/source_pid 都不能单独证明物理输入来源。不能根据停止结果就把责任归到鼠标，也不能用去重掩盖双击语义。

## 最小诊断方案

只给独立自有页面追加 pointerdown/up、mousedown/up、click/dblclick 的记录。计数仍由原来的 onclick 每次增加一次，不阻止、不合并、不模拟任何输入；不监听键盘或保存输入文字。每条记录事件 detail/buttons、页面焦点与页面会话标识。接收服务同时记录宿主 uptime，供逐层配对。

先完全退出 FirstClickProbe，在诊断页记录当前输入设备的前台慢单击和同 Chrome 双窗口后台操作。若仍复现，再用现有 observe 模式记录进入 session tap 的原事件；激活模式保持关闭。必要时在同条件下换触控板比较，而不是先禁用其他日常工具。

该方案只增加 Phase 1 观测；不进入 A4/最终架构，不添加去重、延迟或补点击功能。

## 独立诊断页：短间隔条件复现

R：用户确认，用来激活窗口的第一下也点击同一个“执行普通按钮操作”按钮。短间隔情况下出现 28/29、33/34；慢情况下只有 30。这些试次发生时 FirstClickProbe 已完全退出，代理读取时再次确认没有该探针进程。

| 计数 | 页面 focus 到后续 DOM down | 首组 down/up 时间戳差 | 实际 DOM 序列 |
| --- | --- | --- | --- |
| 28/29 | 217.4 ms | 0 ms | down/up/click(detail=1)，紧接 down(detail=2)，真实松开后 up/click(detail=2) |
| 30 | 577.4 ms | 96.2 ms | 一组正常 down/up/click(detail=1) |
| 33/34 | 195.8 ms | 0 ms | 与 28/29 相同的两组 |

R：两组异常的首组 down、up、click 与第二组 down 使用完全相同的 event.timeStamp；日志还记录后续 dblclick。输入记录本身已是两次 click，原页面 onclick 仍每次增加一次，不能解释成只收一个 click 却把计数加两次。

I/H：这更符合激活点击与后续双击计数/事件重建有关的路径；尚未证明具体生成者是 Chromium、AppKit 或上游工具。focus→DOM down 不是两次物理按压的精确间隔，不能从三组数据得出系统双击阈值或产品等待常数。A3 正在运行并非本轮复现的必要条件；未完全排除先前状态残留。

S：复查 [Chrome 155.0.8059.79 对应版本源码](https://chromium.googlesource.com/chromium/src/+/refs/tags/155.0.8059.79/content/app_shim_remote_cocoa/render_widget_host_view_cocoa.mm#857)：默认只接受活动窗口鼠标事件，acceptsFirstMouse 取决于 embedder 的接受选项。此源码支持激活点击可被拒绝的前提，不能单独证明这次重复序列的生成机制。已审阅事件构造、Blink mouse/event handler、native window 边界文件，尚未定位直接匹配该序列的分支；标签源码也不是安装二进制的完整审计。快照、路径与哈希见 [duplicate-click-source-index.json](activation-context-sources/duplicate-click-source-index.json)。

R：细化证据保存于 duplicate-click-short-interval.json（本地文件 `poc/activation-preserve/runs/20261014-155656/duplicate-click-short-interval.json`，未公开）。保存后重新启动原探针，仅启用 observe，权限和 tap 均具备运行条件；没有启用 A3。下一轮同时记录进入 session tap 的 down/up 与 DOM 序列，并比较同按钮激活与标题栏激活。观察模式是既有主动 tap 返回原事件，不冒充 HID 级原始硬件监测。

## Observe 对照：额外 click 在 session tap 之后出现

R：用户报告同按钮激活快点出现 44/45、48/49、55/56；标题栏激活后快点没有连点。三组逐层配对均确认：系统 down/up 两组（click count 1、2），两次物理 down 间隔分别 194.9、186.4、293.7 ms。没有第三组系统 down/up，observe_only 未激活、事件字段未改动。

R：每组首个系统 down/up 没有对应的 DOM mousedown/up/click；第二个系统 down 之后，网页收到 detail=1 的完整 down/up/click，再收到 detail=2 的 down；这些使用同一 DOM 时间戳。最后真实系统 up 对应第二组 DOM up/click。计数器每收到一个 click 增加一次，两个独立 click 被正常计数。

I：额外 DOM click 的生成发生在所观察的 session tap 之后，当前探针没有制造额外系统事件。仍不能把生成者进一步确定为某一 Chromium/AppKit 实现行，或从 session 层证明硬件原始信号；标题栏对照按用户报告记录，未擅自给其分配计数编号。

证据：duplicate-input-layer-comparison.json（本地文件 `poc/activation-preserve/runs/20261014-155656/duplicate-input-layer-comparison.json`，未公开）。不添加 debounce 或改写 click count；下一步公开窗口级能力评估见 [WINDOW_FOCUS_ADDENDUM.md](WINDOW_FOCUS_ADDENDUM.md)。
