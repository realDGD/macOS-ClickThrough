# Agent Notes

Agent Note 记录长期决策的理由、考虑过的备选和代价。当前行为、使用方法和检查输出分别放在架构、使用文档和验证记录中；不把工作流水账复制为决策。

## 路径与状态

采用 `状态/类别/YYYY-MM-DD-topic.md`：

- `proposed/`：正在讨论或尚未完成的方案。
- `implemented/`：源码和配置已经采用的决策；不表示所有环境都已实机验收。
- `rejected/`：已否决但理由仍有参考价值的方案。

类别按需要使用 `architecture`、`feature`、`bug-fix`、`process` 或 `testing`，不为占位创建空目录。日期表示首次提出该决策的日期。状态变化时移动文件并修正链接。

## 内容

```markdown
# Agent Note: 主题

Status: implemented

## Problem
为何需要作出这个决定。

## Decision
源码与配置实际采用什么。

## Alternatives considered
真实考虑过的备选和未采用的原因。

## Consequences
得到什么、付出什么，哪些结果仍待验证。
```

提案使用 `Proposal` 替代 `Decision`，补充验收条件。只为不能由代码、测试或已有文档充分解释的长期取舍新增笔记；更新已有主题优先于重复建档。历史研究记录和原始日志不迁入这里。

结构参考 [DeepSeek Harness Agent Notes](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/README.md)，未引入其工具链或双语生成流程。
