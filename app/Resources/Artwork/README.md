# 应用图标素材

`AppIcon.svg` 是应用图标的矢量源，采用双层点击波纹与 Lucide Mouse Pointer 2 指针。指针路径保留上游几何，仅调整颜色和位置；圆角背景与波纹独立绘制。

- `AppIcon.png`：1024×1024 预览，圆角底以外透明。
- `../AppIcon.icns`：应用包使用的完整 1×／2× 图标尺寸。
- `Lucide/`：原始 SVG、完整上游许可及固定版本／哈希记录。

在当前 macOS 开发环境中重新生成：

```sh
python3 app/scripts/generate-app-icon.py
```

生成器使用系统 `sips` 和 `iconutil`，无第三方渲染依赖。正常构建直接复制已生成的 ICNS，并将 ISC 许可带入应用包；不在构建时下载素材。详见 [第三方声明](../../../THIRD_PARTY_NOTICES.md)。
