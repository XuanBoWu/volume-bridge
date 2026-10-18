# 音桥（VolumeBridge）

原生 macOS 菜单栏工具。针对不提供原生音量控制的 HDMI／DisplayPort 显示器，在本机调整播放增益。Swift / AppKit 界面，Objective-C++ / Core Audio 音频引擎，不安装驱动。

当前源码版本：0.2.3，已迁移为独立的长期维护项目，并有了正式的应用图标（金门大桥侧视、晴空国际橙，见 [docs/ICON.md](docs/ICON.md)）。英文项目名 VolumeBridge，目录 `volume-bridge`。跨会话背景与当前验收进度见 [AGENTS.md](AGENTS.md) 和 [docs/STATUS.md](docs/STATUS.md)。原型 0.2.0 已有实机与用户验收；迁移、本地化和加图标后的新路径应用仍待首次运行验收。

## 使用

打开 `VolumeBridge.app`，首次启动允许系统音频捕获权限。菜单栏会出现扬声器图标，点击图标打开原生 macOS 控制面板；鼠标悬停可看到应用名称和当前设备状态。

界面跟随 macOS 的系统或应用首选语言：简体中文显示「音桥」，英文显示「VolumeBridge」，无匹配翻译时回退到英文。百分比采用当前区域格式；应用语言更改后需重新启动。菜单、HUD、状态、无障碍描述与音频授权说明均已本地化，详见 [本地化指南](docs/LOCALIZATION.md)。

菜单提供音量滑块、静音、暂停、手动重建链路和退出。显示器默认软件音量为 50%，按设备 UID 保存；50% 对应 0.25 的样本增益，采用平方听感曲线，100% 不衰减，0% 静音。切到原生支持音量的设备后旁路，由 macOS 控制音量。

键盘音量加／减每次调整 6.25%，支持长按；Shift + Option + 音量键每次细调 1.5625%。静音键切换静音，长按不会反复切换；音量加／减会取消静音。按键后浮层显示当前音量或静音状态及设备名，约 1.4 秒后消失，不抢占键盘焦点。调整音量时播放和系统一致的短提示音，响度随百分比变化；静音和非 active 状态保持安静，滑块只在松手确认后响一次。

首次接管音量键需要系统权限，按 macOS 提示开启 音桥。当前 macOS 27 中文系统的页面名为“设备控制和数据访问”；其他版本可能显示“辅助功能”。菜单中的“启用键盘音量键”可重新请求并打开对应设置。构建默认使用一次创建的本地自签名身份，因此重编译不会像 ad-hoc 那样更换 designated requirement；如果本机尚未运行 `zsh scripts/setup-local-signing.sh`，构建会回退 ad-hoc，重新编译后旧授权可能显示为已打开但实际上不再匹配，此时在权限页关闭再打开 VolumeBridge 即可恢复。未授权时菜单滑块仍可用。若键盘被设为标准功能键，请同时按 Fn 使用 F10/F11/F12 的音量功能。

只有当前显示器的软件音量处于 active 状态才接管音量键。切到内置扬声器等原生设备、暂停、睡眠或恢复失败时，音量键交给 macOS。程序仅请求系统媒体事件，过滤音量加、音量减和静音；普通按键不在监听范围内。

暂停和退出会恢复显示器原始播放音量。此版本尚未接入登录启动。

音频不保存、不上传。应用默认在 `~/Library/Logs/VolumeBridge/` 保存结构化运行日志，按 1 MiB 轮转、14 天和 12 MiB 上限清理；日志只记录状态、错误、计数、设备信息和音量幅度统计，没有音频文件。菜单中的“打开日志文件夹”可直接进入日志目录；诊断模式仍可用 `--log 路径` 指定临时日志位置，详细规则见 [本地日志说明](docs/LOGGING.md)。

## 项目维护

- `Sources/`：Swift 界面、媒体键与 HUD，Objective-C++ 音频引擎和纯策略。
- `Tests/`：自动策略测试及需显式运行的硬件验收工具。
- `Resources/`：英文与简体中文 UI 和 Bundle 元数据翻译，以及生成好的应用图标 `AppIcon.icns`。
- `design/icon/`：应用图标的图形源 `icon.py`、生成的 SVG 与预览图。
- `AGENTS.md`：新会话必读的背景、稳定约束、定位顺序和交接维护规则。
- `docs/STATUS.md`：当前实现、检查、实机验收和待完成事项。
- `docs/verification/`：原型阶段和后续验收记录；历史记录保留当时的 DisplayVolume 名称。
- `docs/ARCHITECTURE.md`：音频路径、线程和状态约束。
- `docs/DECISIONS.md`：关键技术取舍、历史缺陷原因与修复约束。
- `docs/LOCALIZATION.md`、`docs/TESTING.md`：文案维护、检查命令和实机测试副作用。
- `docs/LOGGING.md`：本地日志路径、关键事件、轮转与定时清理规则。
- `docs/UI-DESIGN.md`：原生 macOS Popover 的界面结构、状态、权限和交互方案。
- `docs/ICON.md`：应用图标的定稿、设计约束、尺寸档、重新生成方式与设计历程。
- `docs/ROADMAP.md`：已验收项目、待验收项目与开发计划。
- `CHANGELOG.md`：版本变更。
- `scripts/`：检查与诊断工具构建。

构建产物、运行日志和本地诊断状态由 Git 忽略。仓库当前仅保存在本机。

## 已实现

- 修复滑块拖到 100% 后拖不回／跳回：鼠标拖动期间不让定时刷新重设滑块，松手后保留最新值直到后台确认；音量标签立即跟随拖动。
- 媒体键过滤与对应的非激活音量浮层；原生设备旁路，退出时释放事件监听。
- 在音频串行队列内累计按键调整，并再次校验当前输出与设备 UID，避免快速连按丢增量、延迟任务修改已切换的设备。
- 音量键与鼠标滑块共享同一音量状态，较新的键盘操作可接替等待后台确认的鼠标输入。
- 串行管理音频生命周期，合并短时间内重复设备事件。
- 默认输出设备、设备列表、设备存活、采样率、缓冲、流格式变化监听。
- 无原生音量的符合条件显示器自动启用，其余输出旁路或保留原始播放。
- 使用设备 UID 保存音量，不依赖暂时的 AudioObjectID。
- 同一显示器重建时保留临时静音 Tap，成功启动新链路后释放旧 Tap。
- 启动失败后按 1、2、4、8、16、30 秒退避重试。
- 接入 NSWorkspace 睡眠／唤醒通知，睡眠释放资源，唤醒重新检测设备。
- 支持暂停、恢复、手动重建，以及菜单退出／SIGTERM／SIGINT 的正常资源清理。
- 音量渐变按实际采样率计算；立体声同一帧共享增益。
- 实时回调不分配内存、不记录日志、不调用 UI、不等待锁。
- 应用图标：金门大桥侧视、晴空国际橙；16/32/64 px 使用专用简化版本，不是主图直接缩小。

处理范围限定为 HDMI／DP、无输入流、单输出流、双声道交错 Float32 PCM。USB、虚拟设备、多声道或其他格式暂不纳入软件处理。旁路不修改这些设备的原生音量。

## 实机验证

2026-10-08，在 M1 Pro、macOS 27.0、Mi Monitor DisplayPort 上：

- 默认输出切到内置扬声器：进入旁路，回调计数停止增长。
- 切回显示器：自动建链，恢复该设备保存的音量。
- 48 kHz → 44.1 kHz → 48 kHz：真实设备格式变化后重建成功。
- 暂停／恢复、强制重建、模拟睡眠／唤醒入口：状态与资源生命周期正确。
- 有实际音频时重建和切换格式：输入仍非零，输出保持预期增益。
- 静音时输入仍非零而输出为零；取消静音恢复增益。
- 正常 SIGTERM 退出：状态变为 stopped，音频资源释放，进程退出。
- 最终 macOS 14.2 部署目标构建：实机启动、3,107 次回调、定时退出通过，缓冲 mismatch 与过载通知计数均为 0。
- 0.1.1 滑块同步回归测试：旧的 100% 读数不覆盖当前拖动，松手后旧读数不覆盖最新值，确认后恢复同步；覆盖 0% 调高、小数值、设备切换和旁路。
- 0.1.1 实际音频连续调节：100 → 60 → 20 → 100 → 0 → 50 → 100 → 35 → 50，测得增益符合平方曲线（容差 0.002），全程同一链路、mismatch 与过载通知计数均为 0。用户确认鼠标拖动已正常。
- 用户完成真实显示器拔插验证，未发现问题。
- 0.2.0 自动测试：事件解析、音量长按、静音去重、原生输出事件透传、成对释放和停止清理；快速连续调整、范围限制和细调策略均通过。
- 0.2.0 实机处理入口与真实 PCM：4 次加、8 次减、细调、静音／解除、到达 100% 再降低、到达 0% 再升高均通过；浮层显示与自动隐藏、暂停／原生输出时忽略软件调整均通过。测试入口直接调用应用处理方法，没有向 macOS 注入按键。
- 0.2.0 用户已在本机允许媒体键权限，并确认真实音量加、减、两次静音、长按和浮层均正常。

电脑真正睡眠唤醒按用户安排留待后续；AirPods、音频服务崩溃、权限撤销、事件 Tap 超时恢复、8 小时连续运行、全屏应用中的浮层仍待验证。模拟睡眠入口通过不等于真实睡眠已验证；没有过载通知也不等于已经全面证明没有 underrun 或音画延迟。

同设备重建的静音保护已在真实格式切换中运行，但尚未测量重建瞬间的声学输出峰值。程序崩溃或退出后软件衰减消失，不能承诺继续保持退出前的音量。

本地构建默认使用 `VolumeBridge Local Development` 自签名；首次设置运行 `zsh scripts/setup-local-signing.sh`。它只稳定本机代码身份，不提供 Developer ID 信任或公证；没有该身份时构建回退 ad-hoc。最低构建版本为 macOS 14.2，目前只在本机 macOS 27 验证。

## 构建

需要 Apple Command Line Tools 和 Swift 编译器。没有第三方依赖。

```sh
zsh scripts/setup-local-signing.sh  # 首次在本机运行一次
zsh build.sh
open build/VolumeBridge.app
```

统一检查与诊断工具：

```sh
zsh scripts/check.sh
zsh scripts/build-audioctl.sh
python3 scripts/make-test-tone.py work/test-tone.wav
```

测试音生成只创建本地测试素材，不会自动播放。真实硬件验收需手动启动诊断模式，再显式运行对应测试：

```sh
mkdir -p work
open build/VolumeBridge.app --args \
  --status-file "$PWD/work/status.json" \
  --command-file "$PWD/work/command.json" \
  --log "$PWD/work/runtime.log"
python3 Tests/media_integration.py build/audioctl work/status.json \
  work/command.json work/test-tone.wav work/media-results.json
```

运行前退出同一 Bundle Identifier 的旧应用，避免两个软件音量链路或媒体键监听同时运行。普通构建不自动运行上述实机步骤。

默认构建 arm64，实际 Mach-O 部署目标为 macOS 14.2。可以通过 `VB_BUILD_DIR` 改变构建输出路径；Intel 尚未实测。

构建会自动运行状态策略、增益收敛、滑块同步、媒体事件路由、媒体键音量策略、日志轮转和提示音策略测试。统一 `scripts/check.sh` 额外检查：

- 应用图标的声明、打包与 10 个尺寸；
- 资源键、占位符与打包一致性；
- 中英文与语言回退的运行测试；
- Python 语法。

这些检查都不启动音频。实机工具的完整用法、恢复范围与限制见 [测试指南](docs/TESTING.md)。

应用图标已经生成好并提交在 `Resources/AppIcon.icns`，普通构建不需要额外工具。只有修改 `design/icon/icon.py` 后才需要重新生成，这一步需要 Google Chrome 和 ImageMagick，细节见 [图标文档](docs/ICON.md)：

```sh
zsh scripts/build-icon.sh
```

`Tests/audioctl.mm`、`Tests/integration.py` 和 `Tests/live_tone.py` 是显式运行的实机测试工具，不会随普通构建自动修改音频设置。integration.py 临时切换设备和采样率，结束时恢复原设置。

`Tests/volume_regression.py` 配合诊断模式和低幅度测试音验证从满音量调回、从零音量调高；结束时恢复到 50%。它验证真实 PCM 增益，不替代鼠标拖动验收。

`Tests/media_integration.py` 验证媒体键处理入口、HUD 和真实 PCM，临时切换到内置扬声器验证旁路，最终恢复原输出和原音量；真实物理按键另由用户验收。诊断启动可用 `--status-file 路径 --command-file 路径 --log 路径`；`--no-key-permission-prompt` 可跳过自动弹出媒体键授权提示，仍会检测已授予的权限。

产品改名后暂时沿用 `local.alexwu.DisplayVolume` Bundle Identifier，继续读取同一份设备音量设置；首次在新路径打开或重新编译时，macOS 仍可能要求重新授权。公开发布前再确定正式 Bundle Identifier 并规划设置迁移。

## 本机测试用 DMG

```sh
zsh scripts/build-dmg.sh
```

脚本先运行统一离线检查，再生成 `build/VolumeBridge-0.2.3-arm64.dmg`（文件名跟随版本与构建架构），包含 `VolumeBridge.app` 和指向 `/Applications` 的快捷入口。双击 DMG 后，把应用拖入 Applications；启动前确认旧版已退出。脚本不会安装或启动应用，也不会改动音频设备。

打包后自动校验镜像、只读挂载并检查应用签名、全部包内文件及快捷入口，最后卸载验证卷并输出 SHA-256。应用使用本地自签名，没有 Developer ID 或公证；这是本机测试包，其他机器可能被 Gatekeeper 阻止，不能当作已完成正式分发。首次从 Applications 启动及新路径授权仍待人工验收。

## 下一步

先在用户方便时验收新路径应用的中英文界面、授权、旧设备音量设置承接，以及新图标在权限弹窗、系统设置和 Finder 中的显示。真实睡眠唤醒由用户留待后续，之后完成长时间运行验收，再接入登录启动。发布前完善失败恢复、权限引导、代码签名与公证，并测量实际额外延迟。

媒体键授权实现参考 Apple 的 [AXIsProcessTrustedWithOptions 文档](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)；事件监听使用 [CGEvent.tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))，媒体事件字段参照本机 Apple SDK 的 IOKit `ev_keymap.h` 与 `IOLLEvent.h`。
