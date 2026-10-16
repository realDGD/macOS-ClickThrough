# Homebrew tap 自动同步验证（2026-10-16）

> 历史记录：此处为首次跨仓库方案的当时结果。后续已采用 [单仓库 DMG 决策](../../.agents/notes/implemented/process/2026-10-16-single-repository-dmg.md)；旧专用凭据撤销，不再作为当前发布流程。原验证结果保留。

## 改动与权限

[PR #3](https://github.com/realDGD/macOS-ClickThrough/pull/3) 增加 Release `published` 事件同步及 main 分支手动恢复入口。草稿仍由维护者检查后公开，pre-release 同样同步。只更新独立 tap 的 `Casks/clickthrough.rb`，不修改产品 Swift 源码。

用户明确授权建立专用可写 Deploy Key。公钥仅配置于 `realDGD/homebrew-tap`，私钥存放在源码仓库的 Actions Secret；本地临时私钥已删除，未进入 Git 或附件。该密钥可写整个 tap，脚本将改动限制为指定 Cask；有源码仓库写权限的人可能修改工作流来使用 Secret，不能宣称不存在泄露风险。配置和轮换见 [发布指南](../releasing.md)。

## 已完成

- 7 项附件完整性／脱敏检查、6 项真实临时 Git 仓库同步检查通过，覆盖附加 Ruby 拒绝、实际提交／推送、幂等、防降级、同版本不可改写及无关修改隔离。
- 临时签名副本的 5 项打包检查通过，包含已安装 Homebrew 的真实 DSL 解析，不注册 tap、不安装应用。
- [PR CI 38834758770](https://github.com/realDGD/macOS-ClickThrough/actions/runs/38834758770) 在 macOS 15／26 arm64 均通过，包括 Swift 测试、构建、归档校验和 Homebrew DSL。此前一次失败来自打包测试夹具漏复制新增模板模块，已修正后通过。
- [线上同步 38834968672](https://github.com/realDGD/macOS-ClickThrough/actions/runs/38834968672) 由 `workflow_dispatch` 输入现有公开 `v0.1.0`，完成公开状态／tag 来源检查、下载四附件、完整模板与归档校验、专用密钥 SSH 检出及推送 dry-run，返回 `unchanged`。tap 当时仍为 `9e8392234b8882a39eddbb2f5efe1e8a419bd5f0`，没有多余 Cask 提交。
- 本次改动公开文件及实际同步日志的私钥／令牌模式检查无命中；公开文件个人路径模式无命中。只说明这些已检查的模式，不构成所有潜在敏感信息的绝对保证。
- 已安装应用的二进制与运行进程在本轮前后核对一致。未启动新包、改动 TCC／登录项或扩展真实鼠标测试。

## 证据边界

现有版本的线上幂等同步与 SSH 推送 dry-run 已通过；新版本写入／推送在临时 Git 仓库验证。没有为了测试创建虚假版本、替换已公开附件或移动 tag。首次由真实新 Release 发布事件触发的跨仓库 Cask 提交及随后的 tap CI，留待下一次实际发行核验。当前公开版本的下载和安装限制仍见 [首版发布验证](RELEASE_0_1_0_2026_10_16.md)。
