# 分发与 Homebrew

当前通过 [GitHub Releases](https://github.com/realDGD/macOS-ClickThrough/releases) 分发 arm64 开发版，最低部署目标为 macOS 14；[独立 tap](https://github.com/realDGD/homebrew-tap) 提供 Homebrew 入口。当前没有 Developer ID 签名和 Apple 公证，首次打开可能被 Gatekeeper 阻止，更新后可能需要重新添加辅助功能权限。不会通过安装脚本关闭 Gatekeeper、移除 quarantine 或自动授予 TCC 权限。

```sh
brew install --cask realdgd/tap/clickthrough
```

完整命令只信任该 Cask，不要求信任整个 tap，参见 [Homebrew Tap Trust](https://docs.brew.sh/Tap-Trust)。手动安装也可使用 Release 中同一份 ZIP。已有手动安装版本时先自行退出并备份，再迁移至 Homebrew；不要覆盖正在运行的应用。

2026-10-16 的早期核查仅验证了生成器，当时还没有 Release 或可安装 Cask。后续经用户重新授权准备公开开发版和独立 tap；原有 `realDGD/homebrew-cask` 上游 fork 保持不变。首次发行的实际版本、下载与校验结果见 [发布验证](validation/RELEASE_0_1_0_2026_10_16.md)。

## 本地归档

先按 [开发指南](development.md) 构建，再打包选定的应用：

```sh
make package APP=app/build/ClickThrough.app
```

候选包可使用自己的路径，例如 `APP=app/build/macos14-candidate/ClickThrough.app`。归档、SHA-256 和 `release.json` 输出到该应用旁的 `release/`；清单的最低系统版本取自所选应用的 Info.plist。

不提供发布地址时，不生成公开 Cask，并移除输出目录残留的旧 `clickthrough.rb`。回归入口见 [测试说明](testing.md)。

## 生成 Cask

选择真实 HTTPS 发布地址后运行；以下地址仅是占位，不可直接用于安装：

```sh
python3 app/scripts/package-release.py \
  --app app/build/ClickThrough.app \
  --url 'https://YOUR_RELEASE_HOST/ClickThrough-0.1.0-arm64.zip' \
  --homepage 'https://YOUR_PROJECT_HOMEPAGE'
```

Cask 使用 `depends_on arch: :arm64` 与 `depends_on macos: :sonoma`；只接受最低版本声明为 14.0 的包，避免把仍在运行的旧 27 包当作 14 发布。将生成的 `clickthrough.rb` 放入自己的 Homebrew tap 仓库的 `Casks/`，上传这次生成的原始 zip，保持校验值一致。

当前 tap 为 `realdgd/tap`。升级前自行退出应用，再运行 `brew update` 和 `brew upgrade --cask realdgd/tap/clickthrough`。卸载前先在应用中关闭登录启动，再运行 `brew uninstall --cask realdgd/tap/clickthrough`。只有显式 `--zap` 才清理偏好和日志；不宣称能自动清空 macOS 的 TCC 记录。

新版本由 tag 工作流先生成草稿，经检查后公开，再更新 tap 中的 Cask；详见 [发布指南](releasing.md)。公开 ZIP 必须与生成 Cask 时使用的原始 ZIP 完全一致，不重新打包或覆盖已发布版本。

## 正式发布条件

正式签名发行需使用 Developer ID 与 Hardened Runtime，提交公证并确认成功，Staple 到应用后再生成最终 ZIP 和 SHA-256。当前公开版本为用户已选择的未公证开发版；本地打包工具不上传，Release 工作流仅上传到草稿。公开发布和 tap 更新由维护者执行，不安装软件、绕过 Gatekeeper 或更改权限。Intel、旧系统实机和登录行为各按其独立证据报告。

参考：[Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)、[Apple SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)。
