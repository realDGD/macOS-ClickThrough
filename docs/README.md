# 文档目录

## 当前入口

| 文档 | 用途 |
| --- | --- |
| [架构](architecture.md) | 当前组件与 A4 输入路径 |
| [开发](development.md) | 构建、运行、工具链与目录 |
| [测试](testing.md) | 检查命令、实机证据和未验收范围 |
| [分发](distribution.md) | 本地包、签名、公证与 Homebrew |
| [Agent Notes](../.agents/notes/README.md) | 长期决策的理由与备选 |
| [macOS 14 调整验证](validation/MACOS14_2026_10_15.md) | 本次兼容改动与候选包证据 |
| [应用图标接入](validation/APP_ICON_2026_10_15.md) | Lucide 来源、图标资源与候选包检查 |
| [小范围真实鼠标回归](validation/PHASE_3_PHYSICAL_2026_10_15.md) | 调整前产品构建的用户物理输入结果 |
| [安装版撤权恢复](validation/PERMISSION_RECOVERY_2026_10_15.md) | 同一构建、同一进程的权限关闭与恢复结果 |

## 研究与历史

- `research/`：从 Phase 0 API 调研到 PoC 的原始结论与来源；起点是 [Phase 0](research/PHASE_0_RESEARCH.md)，业务结果见 [Phase 1](research/PHASE_1_RESULTS.md)。历史 macOS 27 目标不再是当前部署政策。
- `architecture/PHASE_2_A4.md`：[A4 决策与固定约束](architecture/PHASE_2_A4.md)，平台政策由新 Agent Note 更新，核心路径不变。
- `validation/`：按具体构建、会话记录验证，不把历史结果自动转记为新包实测。
- `superpowers/plans/`：先前批准的实施计划与执行记录，保留原路径。

公开仓库保留研究报告和来源索引；原始运行日志、下载的第三方源码／文档缓存及构建产物仅在本地保存。历史文档中的本机绝对路径已转为可移植路径，原始副本本地保留，实验结论不变。部分历史引用指向未公开的本地证据，不代表这些日志包含在源码仓库中。

[不 raise 研究](research/BACKGROUND_ACTION_RESEARCH.md) 仍暂停；该目录不是恢复实验或扩大测试的授权。
