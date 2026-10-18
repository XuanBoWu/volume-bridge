# 应用图标

最近整理：2026-10-09，源码版本 0.2.3。本文记录图标定稿、生成方式、必须保持的设计约束、验证范围和设计历程。改图标前先读完本文，不要重新从零探索。

## 定稿

晴空国际橙：金门大桥的**侧视图**，国际橙桥体配晴空蓝渐变底。左侧是半个主跨，右侧是一座塔和边跨，桥下有水纹，左上角有柔和的日光。

- 桥对应产品名「音桥 / VolumeBridge」。
- 主跨主缆是一条抛物线，与音桥 `(percent/100)²` 增益曲线同形；吊索由短到长，像一排音量柱。
- 预览：[design/icon/preview.png](../design/icon/preview.png)。

## 文件

| 路径 | 作用 |
| --- | --- |
| `design/icon/icon.py` | 唯一图形源：配色 `PALETTE`、四档几何参数 `MASTER` / `M64` / `S32` / `XS16` |
| `design/icon/AppIcon*.svg` | `icon.py` 的生成结果，提交仅供查看和对比，不要手改 |
| `design/icon/preview.png` | 生成的预览：主图、小尺寸放大、Retina 实际大小 |
| `scripts/build-icon.sh` | 渲染 SVG → 缩小 → `AppIcon.iconset` → `Resources/AppIcon.icns` |
| `Resources/AppIcon.icns` | 已提交的打包结果；`build.sh` 复制整个 `Resources/` 时一并打包 |
| `Info.plist` | `CFBundleIconFile` = `AppIcon` |
| `scripts/check-icon.sh` | 离线检查，由 `scripts/check.sh` 调用 |
| `scripts/app-icon-snapshot.swift` | 导出 macOS 实际显示的图标（IconServices），用于人工核对，只读 |

## 必须保持的设计约束

1. **统一侧视**：从侧面看，近侧塔柱会挡住远侧塔柱，横梁也看不到，所以塔身是一根实心柱身，自下而上分级收窄。不要画正立面的门洞和横梁。用户曾指出旧版把正立面塔楼和侧视主缆拼在一起、塔楼「中空」，与现实不符。
2. **主缆走向**：主缆从塔顶鞍座翻过去，继续沿边跨下垂；边跨主缆接近直线并带吊索；塔身向下一直延伸到水面。
3. **主缆下垂是有意夸张的**：真实金门约为跨度的 1/9。这里加深是为了保留吊索由短到长的音量形状；要改得更写实，先和用户确认。
4. **配色**：背景 `#5DB0FF` → `#2A74E0`；桥体 `#FF7347` → `#D8402A`；日光为白色径向光晕；水纹为白色、32% 不透明；桥体投影为 `#0B3D91`、28%。以 `icon.py` 的 `PALETTE` 为准。
5. **macOS 图标网格**：1024 画布，824 的连续圆角方形位于 (100, 100)，圆角参数 185.4。画面内容全部裁在方形内；macOS 26 起，外形不规则的图标会被系统套进灰色底框。
6. **小尺寸单独绘制**：规则见下表。改主图时必须同步检查三档小尺寸，不能只缩小主图。

## 尺寸档

| 档位 | 文件 | iconset 位置 | 要点 |
| --- | --- | --- | --- |
| 主图 | `AppIcon.svg` | 128–1024 px | 8 单位网格（128 px 下 1 px）；12 根吊索；塔身 3 级 32/48/64；3 行水纹 |
| 64 px | `AppIcon-64.svg` | `icon_32x32@2x` | 16 单位网格；4 根 2 px 吊索；塔身 3 级 2/4/6 px；2 行水纹 |
| 32 px | `AppIcon-32.svg` | `icon_16x16@2x`、`icon_32x32` | 32 单位网格；4 根 1 px 吊索；主缆 1.5 px（1 px 太淡，2 px 在跨中与桥面粘成一条）；塔身 2 px，一列亮一列暗；1 行水纹；不加桥体投影 |
| 16 px | `AppIcon-16.svg` | `icon_16x16` | 64 单位网格；主缆按像素逐格放置（抗锯齿会把橙蓝混成脏紫色）；2 根吊索；不画边跨、水纹和日光 |

Retina 屏上，16 pt 显示 32 px 图，32 pt 显示 64 px 图，所以 32 px 和 64 px 两档最常被看到。权限弹窗约 64 pt，用 128 px 的主图。

## 重新生成

```sh
zsh scripts/build-icon.sh
zsh scripts/check.sh
```

依赖：

- Google Chrome：路径不同时用 `VB_CHROME` 指定。
- ImageMagick：命令为 `magick`。
- 系统自带的 `iconutil`，以及 `python3`。

普通构建只复制已提交的 `.icns`，不需要这些工具。

流程：

1. `icon.py` 写出四个 SVG。
2. headless Chrome 把每个 SVG 渲染成 1024 px 图。
3. 在线性光下用 Box 滤镜按整数倍缩小，每个输出像素恰好是对应方块的平均值。
4. 按 iconset 规则组装 10 个文件，用 `iconutil` 生成 `Resources/AppIcon.icns`，同时输出 `design/icon/preview.png`。

脚本已处理一个坑：headless Chrome 截图后可能不退出，或者弹出钥匙串授权。所以脚本使用 mock keychain 和隔离的临时配置目录，看到 PNG 写出后就结束进程。中间文件放在 `build/icon/`。

2026-10-09 在同一台机器上重复生成，`.icns` 逐字节一致。换机器或换 Chrome 版本后，像素可能有细微差别，属正常。

## 验证

- **自动检查**：`scripts/check-icon.sh` 检查 `CFBundleIconFile`、打包进 App 的文件与 `Resources/` 一致、10 个尺寸像素正确。已做过反例测试：缺图标时会失败。
- **系统显示**：2026-10-09 在 M1 Pro / macOS 27.0 上，对 `build/VolumeBridge.app` 运行 `swift scripts/app-icon-snapshot.swift build/VolumeBridge.app build/icon-snapshot.png 512`。系统显示新图标，没有被套灰色底框；取 64 px 时用的是 64 px 专用版本，系统会再做一次轻微重采样。
- **图标缓存**：`build.sh` 结束时会 `touch` App，刷新图标缓存。若 Finder 仍显示旧图标，可以重开窗口，或运行：

  ```sh
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f build/VolumeBridge.app
  ```

- **未验证**：
  - Finder 窗口、系统设置隐私列表、权限弹窗里的实际显示（随 0.2.3 新路径首次启动一并检查）。
  - macOS 26 起的深色、着色、透明图标外观：`.icns` 没有分层，系统自动处理后的效果未看过。
  - 非 Retina 外接显示器上的 16 px 显示。

## 为何不用 Icon Composer / Asset Catalog

本机只有 Command Line Tools，没有 Xcode 的 `actool` 和 Icon Composer，项目也不使用 Xcode 工程，所以用系统自带的 `iconutil` 生成 `.icns`。将来若改用 Xcode 构建，可以把 `AppIcon.svg` 拆成图层导入 Icon Composer，以获得系统的玻璃质感和深色、着色外观。

## 设计历程（避免重复探索）

1. **GPT 草稿**：深灰圆角底 + 银色显示器 + 喇叭 + 滑块。用户认为太丑，放弃。
2. **第一轮，6 个方向**：声波月桥、斜拉桥音量楔、显示器扬声器、音量旋钮、衰减波形、悬索桥滑块。用户选了斜拉桥音量楔：一束平行拉索的轮廓即音量楔 ◢。
3. **第二轮**：斜拉桥出 8 套配色，同时探索金门造型，包括单塔平面风格、国际橙，以及写实的晴空、暮色、雾中塔楼。用户选金门单塔平面风格。
4. **第三轮**：用户指出侧视的金门塔楼应为实心、旧图视角混用。改为统一侧视后再出 8 套配色，用户选晴空国际橙。
5. **第四轮**：做小尺寸专用版本和像素对齐。

探索文件在被 Git 忽略的 `work/icon-design/` 下，包括 GPT 草稿和 `claude-concepts/` 各轮脚本与对比图。它们不是源码，可以删除；一切以 `design/icon/` 为准。

## 发布前注意

- 金门大桥是知名地标。公开发布或商用前，应确认地标造型是否有商标或授权要求；本机自用不受影响。
- 菜单栏图标仍是 SF Symbol `speaker.wave.2` / `speaker.slash`（模板图标，跟随系统外观），与 App 图标无关。是否改成与 App 图标呼应的模板图，另行讨论。
