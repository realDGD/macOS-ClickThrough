# Phase 3 小范围真实鼠标回归

日期：2026-10-15。正式应用：ClickThrough 0.1.0 (1)，图标调整后构建，二进制 SHA-256 `6f6e1b585e20ebaf5db0ddb9a69cf36a708986be27a29d2ff01b8c990cd1d57d`。继续使用当前进程和原 A4 引擎，不用 Computer Use 代替关键鼠标输入。

原生靶标会话：`app/verification/20261015-physical.vpXI3R/target-events.jsonl`，PID 25223。产品日志：`~/Library/Logs/ClickThrough/session-BD96CBD0-89C5-40DC-9874-FEA549F4B49C.jsonl`，结束时快照保存在同一会话目录的 `product-events.jsonl`，汇总在 `summary.json`。诊断临时开启，结束时已通过原生设置恢复关闭，功能保持开启；测试靶标已正常退出。

| 场景 | 用户反馈 | 日志证据 | 结论 |
| --- | --- | --- | --- |
| 功能开启，从 Codex 直接单击后台靶标左侧一次 | 0→1 | reject 区域仅一组 left_down / left_up，click_count=1，action_executed=true、count=1、dragged=false、inside=true。产品 event 3962 对应同一靶标，AXMain/AXFrontmost 均返回 0；即时 frontmost 读回为 false，原样保留 | 本次首次点击实际执行通过；后台准备依据用户执行步骤，业务执行有独立靶标日志 |
| 从 Codex 回到靶标左侧双击 | 1→3 | 两组真实 down/up，click_count 分别为 1、2，两次 action_executed=true，count 依次为 2、3；产品 event 3975、3976 对应。3975 的即时 AXFrontmost 读回错误 -25204，写入均成功，错误原样保留 | 两次实际操作执行，双击计数语义保留；不因即时读回错误否认独立业务结果 |
| 从 Codex 回到左侧按住拖出区域再松开 | 3→3 | left_up：had_down=true、dragged=true、inside=false、action_executed=false、count=3；产品对应 event 3978 | 拖出取消通过 |
| 取消后正常单击 | 3→4 | 下一组 down/up：dragged=false、inside=true、action_executed=true、count=4；产品对应 event 3979 | 取消后恢复通过 |
| 后台右键并选择“记录菜单操作” | 菜单打开、菜单选项执行各 +1 | 靶标 right_menu_open count=1，menu_action count=1；产品 event 3987 为 rightMouseDown，窗口与应用 AX 写入均为 0 | 右键菜单打开及实际菜单动作通过；右键原生行为保留 |
| 左键菜单栏图标关闭，再单击后台靶标 | 4→4 | 产品记录 stopped；随后靶标 accepts_first_mouse=false，没有对应的 left_down/left_up/action；恢复开启前没有新的产品 activation_request | 本轮关闭状态与原生拒绝首次点击行为符合；不将日志静默单独当作系统监听释放的枚举证明 |
| 左键菜单栏图标重新开启，再单击后台靶标 | 4→5 | 产品记录 started，随后 event 3995 对应靶标；靶标 action_executed=true、count=5 | 本轮重新开启及首次操作恢复通过 |
| 右键菜单栏图标，选择设置 | 设置能打开，仍显示“已开启” | 菜单交互依据用户物理输入反馈；随后原生 AX 界面独立确认已开启 / pointer.arrow.click.2 | 右键设置入口不切换功能状态，本轮通过 |

本轮小范围真实鼠标回归完成并通过，未改动引擎或重新构建。首次文本输入、浏览器真实复制尚未在本次产品二进制上新增验收；登录重启、撤权恢复和更广环境仍未验收，不从原生靶标或历史 PoC 结果外推。
