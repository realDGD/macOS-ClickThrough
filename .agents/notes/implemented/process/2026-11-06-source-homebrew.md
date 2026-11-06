# Agent Note: Homebrew 使用固定源码与 CLT 本机构建

Status: implemented

## Problem

旧 Cask 下载 GitHub Release 的预编译 DMG，用户希望改为 VoiRemote 的本机源码编译方式，并沿用已验证的固定身份。源码构建、系统授权和 Apple 公证是不同事项。

## Decision

Homebrew 改为固定完整提交的 GitHub 源码归档，并验证 SHA-256。使用当前支持的 `preflight_steps` 调用 Swift 6 Command Line Tools 构建，标准 `app` artifact 管理安装与卸载，`postflight_steps` 只清除本次构建缓存。不引入 VoiRemote 的 CLI 或登录项恢复实现，本项目没有同样的安装维护接口需求。

外层已有 Homebrew 文件准备沙盒，SwiftPM 使用同一源码目录内的缓存、配置与安全状态目录，并关闭 SwiftPM 的嵌套构建沙盒；不关闭外层 Homebrew 沙盒或系统保护。仅在当前构建 shell 中导出 Swift 包装函数，已固定的源提交和现有构建入口保持原样。

Cask 的构建命令由 `app/scripts/source_cask.py` 单点生成；调用源码已有的构建与签名入口，写入无个人路径的来源凭据后重新签名，显式使用 identifier-only ad-hoc 身份。默认手动构建和手动 DMG 流程保持原样，A4 不变。

首次转换固定已合并提交 `3e60ffd386f93445787f898eab9d4f7f263c65d4`，该提交包含授权入口与签名能力；应用版本仍为 0.1.3，旧 DMG 安装用户使用一次 `brew reinstall` 迁移。后续公开 Release 触发的同步改为校验标签对应源码归档并生成源码 Cask，不再把 DMG 下载清单写回仓库入口。

## Alternatives considered

- 持续下载未公证 DMG：保留手动下载，但不再作为当前 Homebrew 方式。
- 每次编译 main/HEAD：内容可移动且无法固定校验，不采用。
- 直接复制 VoiRemote 的自定义安装器、登录维护 CLI：超出本项目编译安装需求，继续用标准 app artifact。
- 清除 quarantine 或关闭 Gatekeeper：不采用；本地编译不能替代 Apple 公证，也不自动授予权限。

## Consequences

用户需要已安装支持 Swift 6 的现代独立 CLT；安装不自动下载工具链。仍限 arm64 与 macOS 14 部署目标，不扩展平台矩阵。固定身份只校验标识，不认证签名者；首次迁移可能需要重新授权，不能把本机构建视为通用权限或首次启动保证。

历史 DMG、旧签名研究与验证保留。当前证据见[验证记录](../../../../docs/validation/SOURCE_HOMEBREW_2026_11_06.md)。
