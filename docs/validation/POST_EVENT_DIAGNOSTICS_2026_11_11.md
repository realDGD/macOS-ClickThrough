# 放行后诊断规则与验证（2026-11-11）

## 目的与范围

用户反馈 MacShot 截图编辑窗口偶发需要多次点击激活，之后自行恢复。现有现场存在 `AXWindow` 读取 `attributeUnsupported`，但未记录命中元素的 role／subrole，无法证明故障原因。本次只增强可选详细日志，不修复或改变 A4 激活逻辑，不增加重试、窗口解析 fallback 或事件重放。

版本为 0.1.5 (8)。此前取消的多屏菜单定位功能保持移除，不随此版本恢复。

## 日志规则

| 记录／字段 | 用途与边界 |
| --- | --- |
| `started` 的 `version`、`build`、`pid`、`detailed`、`schema=2` | 标记引擎启动时的版本、进程和采集级别 |
| 详细 down、跳过、请求、快照中的 `click_id` | 原事件时间戳与事件编号组合，连接同一次点击；保留原事件编号和时间字段 |
| `frontmost_pid_before_request`、`frontmost_bundle_id_before_request`、`before_request_sample_ns` | 请求前 NSWorkspace 报告的前台应用及采集时刻，不是新增 AX 查询 |
| `focused_window_before_request=not_sampled` | 明确未同步读取精确前置焦点，不能将后置采样当作前置状态 |
| `hit_ax_error`、`hit_pid`、`hit_pid_error` | 原有命中与 PID 调用的结果，不额外命中一次 |
| `window_resolution=AXWindow_attribute`、`window_attribute_error`、`window_attribute_type` | 原有 AXWindow 解析路线、错误和返回 CF 类型；不存在值时为 `missing` |
| `post_event_snapshot` | 原事件回调返回后，通过主队列延后 150 ms 再在后台串行读取；不等待、不重发原点击 |
| `hit_role`、`hit_subrole` | 同一命中引用在采样时的属性，不是点击当刻属性的保证 |
| `focused_window_status`、`focused_window_ax_error`、`focused_window_type` | 目标应用报告的焦点窗口；读取失败／类型不符为 `unavailable`，不能解释为“没有焦点” |
| `focused_matches_hit`、`focused_matches_resolved_window` | 有焦点窗口时与保留引用的 CFEqual 结果；没有可比较引用则不填写，不伪造 false |
| `resolved_main`、`resolved_focused` | 解析窗口在采样时的 AXMain／AXFocused；不支持时记录错误，不改写属性 |
| `frontmost_pid_at_snapshot_start/end`、开始时 bundle ID | AX 读取前后 NSWorkspace 报告的前台应用；快照不是原子状态 |
| `snapshot_started_ns`、`snapshot_finished_ns`、`snapshot_delay_ns`、`ax_observation_work_ns` | 单调时钟采样边界、实际延迟与读耗时；JSON 行的 `time` 是提交写入时间 |
| `latest_click_id`、`intervening_click` | 采样完成回到主线程时是否收到另一轮 down，提醒后续输入可能影响焦点 |
| `post_event_snapshot_skipped`、`reason=observer_busy` | 已有一组待执行／执行中，明确跳过，不堆积 AX 工作 |
| 各属性的 `*_ax_error`、`*_timeout_error`、`*_type`、`*_status=budget_exhausted` | 区分错误、返回类型与预算限制，不把未知当成功或 false |

激活请求内继续保持原有的窗口 AXMain → 应用 AXFrontmost → 返回同一真实事件，既有 guard、消息超时和即时读回顺序不变。详细关闭时不保留 AX 引用、不安排新增查询；基本诊断仅增加引擎启动元数据。

采样仅一个槽位，单次查询超时 25 ms。累计达到 100 ms 后不启动下一次读取，最后一条已经启动的读取仍可消耗其超时，因此 100 ms 不是整组硬截止时间。停止、监听失效、诊断级别变化使结果失效；已开始的只读采样仍可能短暂完成，但不会继续写入旧结果。旧槽位释放后才能安排下一组。

日志继续使用原开关和持久化设置，默认均关闭。现有 2 MiB 轮换、7 天过期、20 MiB 总容量及专用文件清理范围均未改变。不记录窗口标题、正文、键盘、截图、剪贴板或 AX 对象描述。

## 已执行的检查

- 本机 macOS 27.2.1 / arm64：`make test`，20 项测试通过。包含既有 17 项规则、A4 顺序、设置迁移和日志保留检查，以及 3 项新增延后／单槽、关联与新点击、关闭／失效抑制检查。新增检查只注入只读采样结果，不查询真实应用。
- 使用独立 CLT Swift 6.4.2 构建到新的候选目录，不启动候选或覆盖运行实例。固定标识 ad-hoc 签名通过严格校验，最低部署声明与 Mach-O 保持 macOS 14 / arm64。
- 提交前复核同步激活代码：新增采集仅保存既有查询结果和引用；窗口与应用的 AX 操作、失败分支及原事件返回保持原顺序。

本地构建和自动检查不证明间歇故障已修复，也不是 macOS 14 实机、原点击业务或新日志在目标现场的验收。PR CI、远端 Cask 和安装结果按实际完成状态单独报告。详细模式增加后台 AX 服务负载，采样可能受应用响应、窗口销毁或后续输入影响；下一次故障需结合准确时间和独立的用户反馈判读。
