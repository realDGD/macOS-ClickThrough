# Agent Note: 同仓库 Homebrew 与 DMG 分发

Status: implemented

## Problem

独立 tap 令单个应用多维护一个仓库，并需要长期跨仓库写密钥。ZIP 首版能安装，但手动用户缺少 DMG 的拖入“应用程序”入口。用户要求合并 tap、当前及后续改用 DMG、撤销额外凭据，并保留已公开 v0.1.0 和当前安装状态。

## Decision

将 `Casks/clickthrough.rb` 放入项目根目录。Homebrew 保留 `realdgd/tap/clickthrough` 名称，通过 `brew tap --custom-remote` 显式指定项目 URL，已有用户可以只更换来源。旧独立仓库保留历史 Cask 和迁移说明，停止维护新版本，不删除用户历史。

v0.1.1 起发布一个标准 HFS+ / UDZO DMG，包含应用和 `/Applications` 快捷方式，由系统工具生成，供手动下载与 Homebrew 共用。v0.1.0 的 tag、ZIP 和四附件均保持原样，不在原版本上替换归档。

tag 仍生成草稿；公开后使用本仓库 `GITHUB_TOKEN` 写入单个 Cask，撤销旧 Deploy Key 与额外 Secret。同步前检查来源、原生应用、DMG 内容及完整 Cask 模板；只读挂载、不打开窗口、不启动应用，并保证卸载。相同内容不提交、旧版本不降级、同版本不改写、并发推送不强制覆盖。

## Alternatives considered

**独立 tap。** 一条简短安装命令方便，也适合维护多个软件，但为当前单应用增加仓库和密钥成本，因此迁移至同仓库。

**同时维护 ZIP 与 DMG 两条新发布路径。** 增加归档、校验及 Cask 来源选择的维护负担。用户已要求 DMG，新的发行使用一个主要安装包。

**替换 v0.1.0 附件。** 会破坏已公开版本的字节稳定性和已有 SHA-256，明确不采用；本次以新 v0.1.1 完成迁移。

## Consequences

首次安装需显式 URL，Homebrew 会克隆整个项目，tap 更新流量大于单文件仓库；已安装旧 tap 者可保留名称并换源。内置 token 的提交通常不再触发 CI，因此原生和 Homebrew 检查在同步 job 内、提交前完成。

DMG 不带来 Developer ID 或 Apple 公证，也不自动解决 Gatekeeper 或 TCC。该改动不影响 A4 核心、不安装候选包、不新增鼠标业务或应用矩阵验收。实际发布、旧资产保持及凭据撤销分别记录证据，不能由本地构建代替。命令见 [发布指南](../../../../docs/releasing.md)。
