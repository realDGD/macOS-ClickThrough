# 分发与 Homebrew

当前提供本地 arm64 开发包和 Cask 生成工具，最低部署目标为 macOS 14。尚未发布公开下载、Homebrew tap、Developer ID 签名或公证版本。

2026-10-16 已再次通过现有五项分发检查，包括 Homebrew 7.0.9 的真实 Cask DSL 解析；这是生成器验证。公开源码仓库 [macOS-ClickThrough](https://github.com/realDGD/macOS-ClickThrough) 尚无 Release 安装归档，现有 `realDGD/homebrew-cask` 是上游 fork、没有 ClickThrough 定义，因此目前没有可直接安装本项目的 `brew install` 命令。本轮仅检查，不注册或修改 tap。

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

发布归档及专用 Homebrew tap 准备好后，用户才可使用以下命令，`OWNER` 替换为实际发布账号：

```sh
brew tap OWNER/tap
brew install --cask OWNER/tap/clickthrough
```

升级使用 `brew upgrade --cask OWNER/tap/clickthrough`。卸载前先在应用中关闭登录启动，再运行 `brew uninstall --cask clickthrough`。只有显式 `--zap` 才清理偏好和日志；不宣称能自动清空 macOS 的 TCC 记录。

## 正式发布条件

使用 Developer ID 与 Hardened Runtime 签名，提交公证并确认成功，Staple 到应用后再生成最终 zip 和 SHA-256。当前工具不会上传、安装、注册 tap、绕过 Gatekeeper 或更改权限。Intel 包、旧系统实机和登录行为仍按独立证据验收。

参考：[Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)、[Apple SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)。
