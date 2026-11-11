# 当前架构

ClickThrough 是一个原生菜单栏进程，使用 AppKit、SwiftUI 和系统公开接口。最低部署目标及理由见 [平台决策](../.agents/notes/implemented/architecture/2026-10-15-macos14-platform.md)。

## 输入路径

Session event tap 同步收到鼠标事件后，先按原有规则筛选未修饰的左右键 down，公开命中窗口并校验 owner PID。窗口 AXMain 写入成功后请求应用 AXFrontmost，最后返回同一个真实事件。up、drag 和不符合条件的事件保持通过。

固定顺序、超时语义、失败处理和系统限制以 [Phase 2 A4 决策](architecture/PHASE_2_A4.md) 为准。平台调整不改这一组逻辑，也不引入事件重放或应用专用操作。

## 源码责任

| 位置 | 责任 |
| --- | --- |
| `app/Sources/ClickThroughCore/` | 持久化设置、规则、修饰标志政策、运行状态、AX 步骤顺序和本地诊断存储 |
| `EventTapEngine.swift` | 监听生命周期、同步处理与原事件放行 |
| `WindowResolver.swift` / `A4Activation.swift` | 窗口命中与 A4 AX 操作 |
| `AppModel.swift` | 用户意图、实际引擎状态、偏好与界面协调 |
| `StatusItemController.swift` / `SettingsView.swift` | 菜单栏左右键入口与设置 |
| `LoginItemController.swift` / `AppDelegate.swift` | 登录项、手动重新打开和窗口生命周期 |
| `ClickThroughCore/Diagnostics.swift` | 普通／详细诊断开关，后台编码与写入，文件轮换、按年龄和总容量清理 |

应用规则只按 bundle ID 筛选；不包含对业务按钮、剪贴板或网页内容的识别。运行状态与用户的开启意图分开保存，权限失败不能伪装成已开启。

## 范围

`app/` 是产品源码，`poc/` 是保存的探针与独立靶标。没有 helper、驱动或运行时第三方依赖。不 raise 方向仍停留在 [已暂停研究](research/BACKGROUND_ACTION_RESEARCH.md)。

组件实现与构建可用性不直接证明首次点击业务成功。实际证据和待验收范围见 [测试说明](testing.md)。

## 分发路径

产品与 Homebrew Cask 共用此仓库。Homebrew 下载固定源码归档，在受限文件准备步骤中使用独立 CLT 编译，以固定标识签名后由标准 app artifact 安装。`source_cask.py` 单点生成构建命令、来源凭据和 Cask；不引入额外 helper 或登录维护接口。tag 工作流保留手动 DMG 草稿；公开 Release 后，另一个工作流校验标签源码归档并使用仓库内置 token 仅更新 `Casks/clickthrough.rb`。见[发布指南](releasing.md)和[源码构建决策](../.agents/notes/implemented/process/2026-11-06-source-homebrew.md)。
