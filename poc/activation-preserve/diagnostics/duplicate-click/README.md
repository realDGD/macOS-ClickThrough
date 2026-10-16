# 连点诊断页

Phase 1 观测工具；原按钮 onclick 保持每次 click 计数 +1。只新增 capture 阶段鼠标事件及页面焦点日志，不合并、不阻止、不模拟任何输入。不监听键盘或保存输入/剪贴板原文。

与原 9593 服务并行，独立端口 9594，独立运行目录及页面会话 UUID。HTTP 记录包含 mach_absolute_time 转换的宿主 uptime，供与探针 Dispatch uptime 比较；接收时间晚于实际 DOM 事件，仍需考虑日志传输延迟。

第一轮完全退出探针，用外接鼠标慢单击与同 Chrome 双窗口后台对照。后续如需 session tap 观测，只使用现有 observe 模式，保持所有激活模式关闭。结果由用户物理输入与原始日志决定。
