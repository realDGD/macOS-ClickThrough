# 安装版撤权恢复验证

日期：2026-10-15。用户授权安装带图标的新版本、退出旧版并开始撤权恢复测试。

## 安装与初始状态

ClickThrough 0.1.0 (3)，arm64，最低 macOS 14.0，已从 `app/build/app-icon-candidate/ClickThrough.app` 复制到 `/Applications/ClickThrough.app`。安装前目标路径不存在，旧进程已退出。复制后严格验签通过，二进制 SHA-256 为 `3819b1c369d6b42456b34f2ce467756b860285bec1d6feb81bbb2df233c0bc91`。

首次打开提示需要权限；用户完成新安装位置的初始授权后，原生 AX 界面确认已开启、图标为 `cursorarrow.click.2`。这是初始安装授权，不计为撤权恢复通过。

诊断临时开启，测试使用既有 FirstClickTarget 与新会话目录 `app/verification/20261015-permission-recovery.0_hv8afo/`。未更改 A4 源码、未重编译或更换测试二进制，未操作登录项。

## 试次

| 阶段 | 状态 |
| --- | --- |
| 授权正常时的真实后台单击基线 | 通过：用户反馈 0→1；靶标一组 down/up、action_executed=true、count=1，产品 event 781 对应；安装版 PID 34029 与二进制保持不变 |
| 用户关闭权限后的状态与原生基线 | 通过：系统 AX 树确认开关 off，应用显示需要辅助功能权限／cursorarrow.click；用户报告后台单击 1→1，随后前台单击 1→2。靶标记录 accepts_first_mouse=false，后一组 down/up 的 action_executed=true、count=2；产品未新增激活请求。PID 34029 与二进制未变，没有重开 |
| 同一构建重新授权、手动开启后的实际业务恢复 | 通过：用户重新打开同一权限条目，系统开关 on；点击“开启”后状态恢复。用户真实后台单击 2→3；靶标仅一组 down/up，click_count=1、action_executed=true、count=3，对应产品 event 841。PID 34029、二进制与核心源码哈希未变，全程未重启 |

## 结论与范围

本机 macOS 27 的同一构建、同一进程撤权恢复通过：权限关闭后功能停止，重新授权并手动点击“开启”后，后台首次单击重新执行实际操作。重新授权后不自动启动引擎；本次明确包含手动开启步骤。该结果不覆盖构建／签名变化、macOS 14 实机、登录重启或更广环境。

event 841 的 AXMain、AXFrontmost 均返回 0，即时 application_frontmost 读回仍为 false；原始值保留，以独立靶标实际执行为业务成功依据，不将 AX 返回值或焦点读回单独视为通过。

诊断已恢复关闭，独立靶标已正常退出，安装版保持已开启、原 PID 不变。原始靶标日志、产品日志快照、会话元数据和摘要保存在 `app/verification/20261015-permission-recovery.0_hv8afo/`。未改源码、未重新构建、未操作登录项或扩大应用范围。
