# 国际化与本地化

当前支持英文 `en` 和简体中文 `zh-Hans`，源码版本 0.2.2。界面名分别为 VolumeBridge / 音桥；仓库、二进制与 `.app` 文件名保持英文。

## 语言与区域

`CFBundleDevelopmentRegion` 是 `en`。macOS 根据系统或应用首选语言，从可用翻译中选择最合适的语言；没有匹配语言时回退到英文。当前没有应用内语言选择器。修改应用语言后重新启动才能统一刷新已经创建的菜单和后端说明。

语言与区域分别处理。百分比使用 `Locale.current` 的 NumberFormatter，例如美国英语显示 `50%`，法国区域显示 `50 %`；区域间隔不应被手动去掉。实际设置仍存储数字，展示为四舍五入的整数百分比，细调值保持原精度。

## 文件和覆盖范围

- `Resources/en.lproj/Localizable.strings`、`Resources/zh-Hans.lproj/Localizable.strings`：44 个 UI 键，包括菜单、状态、错误、媒体键授权状态、HUD、无障碍描述。
- 各语言 `InfoPlist.strings`：CFBundleDisplayName 和 NSAudioCaptureUsageDescription。
- `Sources/Localization.swift`：Swift 文案、模板、百分比、机器状态到标签的映射。
- `Sources/AudioController.mm` 中的 `l10n`：在非实时路径读取后端状态说明与 Tap 名称。
- `build.sh`：复制 Resources 后签名；缺少资源时构建失败。

设备名采用系统原始名称。Bundle ID、诊断 JSON 键与 `active` / `bypass` 等状态值、测试协议、内部类/队列名不翻译。历史验收文档保留原名和原文。

应用图标 `Resources/AppIcon.icns` 不含文字，所有语言共用一份，不放进 `.lproj`；以后如果给图标加文字，必须同时考虑本地化。

## 新增或修改文案

1. 使用稳定的点分键，在两份 Localizable.strings 同时加入完整句子。
2. 动态值用 `%@` / `%d`；需要改语序时用 `%1$@` 等位置参数。两种语言占位符的位置与类型必须一致。
3. 调用 L10n.text / L10n.format；不硬编码中文，不将句子拆成只能按一种语序拼接的片段。
4. 百分比调用 L10n.percent；不直接附加 ASCII `%` 代替正常区域格式。
5. 同步无障碍描述与授权说明。资源查找不放进 IOProc。
6. 运行统一检查；改变布局或长文案时再检查真实中英文菜单与 HUD，不把资源测试视为视觉验收。

添加语言时扩展 `.lproj`、Info.plist 的可用语言清单，并加入对应运行案例。资源检查自动遍历所有 `.lproj`，运行检查的语言案例在 `scripts/test-localizations.sh` 中维护。目前未做繁体中文、RTL 或其他语言布局验收。

## 验证

```sh
zsh scripts/check.sh
```

检查资源可解析、键集合一致、占位符一致、源码引用存在、打包内容一致、源码没有中文硬编码。专用 LocalizationTests.app 验证英语、简体中文、法语偏好下英文回退和法国区域百分比；还检查本地化 Bundle 元数据、授权说明与控制器初始状态。测试不创建捕获链路。

0.2.2 上述检查通过。中英文真实菜单布局、系统权限提示和新路径首次启动仍待验收。用户文档目前以中文维护；面向公开发布的完整英文用户文档还未编写。
