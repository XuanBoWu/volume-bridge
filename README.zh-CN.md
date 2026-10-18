[English](README.md)

# 音桥（VolumeBridge）

原生 macOS 菜单栏工具，让没有原生音量控制的 HDMI / DisplayPort 显示器也能调节播放音量。

- 支持滑块、静音按钮和键盘音量键。
- 调节时显示音量浮层，并播放随音量变化的提示音。
- 跟随系统输出，或选择固定目标设备。
- 音频仅在本机处理，不安装驱动、不录音、不上传。

音桥使用 Core Audio Process Tap 和软件衰减，不依赖 DDC，也不改造控制中心的音量滑块。原生支持音量控制的设备继续交给 macOS。

## 使用要求

- Apple 芯片 Mac，默认构建 arm64。
- 部署目标为 macOS 14.2；目前实机仅验证 M1 Pro / macOS 27，旧系统和 Intel 尚未验证。
- 软件调音量暂限 HDMI / DisplayPort、无输入流、单输出流、双声道交错 Float32 PCM，且无可写原生音量的设备。
- 从源码构建需要包含 Swift 和较新 macOS SDK 的 Apple Command Line Tools。

## 构建与启动

```sh
zsh build.sh
```

先退出正在运行的旧版，再打开 `build/VolumeBridge.app`。首次启动按提示授予音频捕获和音量键控制权限。

构建优先使用本机开发签名，没有时使用 ad-hoc。若希望多次重新构建后保持本机签名身份稳定，可以在首次构建前运行一次：

```sh
zsh scripts/setup-local-signing.sh
```

本地签名不等于 Developer ID 或公证。当前仓库提供源码和本机测试打包流程，尚未提供经过公证的公开发行版。

可选的签名初始化脚本需要 OpenSSL 3，普通构建和 ad-hoc 检查不需要。

## 使用

点击菜单栏图标，选择设备、调节音量、静音或暂停。固定目标只有成为系统输出后才会被接管；选择目标不会自动切换 Mac 输出，需要使用面板中明确的切换操作。

软件接管生效时处理键盘音量键；其他输出和暂停状态交给 macOS。界面支持英文和简体中文。

**暂停、退出或崩溃后，软件衰减会消失，恢复显示器原始播放音量。**

## 隐私与日志

音频只在内存中处理，不保存、不上传。本地日志记录设备信息、状态、错误、计数和音量幅度统计，按 1 MiB 轮转，总上限 12 MiB，轮转文件最多保留 14 天。分享前请检查设备名称和标识符。详见[日志说明](docs/LOGGING.md)。

## 开发

```sh
zsh scripts/check.sh
```

检查不会启动音频捕获、播放声音、切换设备或申请权限。明确使用 ad-hoc 构建可运行 `VB_SIGN_IDENTITY=- zsh scripts/check.sh`。

参见[贡献指南](CONTRIBUTING.md)、[测试指南](docs/TESTING.md)、[架构](docs/ARCHITECTURE.md)和[路线图](docs/ROADMAP.md)。真实睡眠/唤醒、长时间运行及更多设备兼容性仍待验证。暂不配置 GitHub Actions CI，由本地执行检查。

## 许可证

[MIT](LICENSE)。素材及平台资源说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
