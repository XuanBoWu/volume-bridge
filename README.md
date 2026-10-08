# 音桥（VolumeBridge）

原生 macOS 菜单栏工具。针对不提供原生音量控制的 HDMI／DisplayPort 显示器，在本机调整播放增益。Swift / AppKit 界面，Objective-C++ / Core Audio 音频引擎，不安装驱动。

当前版本：0.2.1，已迁移为独立的长期维护项目。英文项目名 VolumeBridge，目录 `volume-bridge`。

## 使用

打开 `VolumeBridge.app`，首次启动允许系统音频捕获权限。菜单栏会出现扬声器图标，鼠标悬停可看到 音桥 和当前设备状态。

菜单提供音量滑块、静音、暂停、手动重建链路和退出。显示器默认软件音量为 50%，按设备 UID 保存；50% 对应 0.25 的样本增益，采用平方听感曲线，100% 不衰减，0% 静音。切到原生支持音量的设备后旁路，由 macOS 控制音量。

键盘音量加／减每次调整 6.25%，支持长按；Shift + Option + 音量键每次细调 1.5625%。静音键切换静音，长按不会反复切换；音量加／减会取消静音。按键后浮层显示当前音量或静音状态及设备名，约 1.4 秒后消失，不抢占键盘焦点。

首次接管音量键需要系统权限，按 macOS 提示开启 音桥。当前 macOS 27 中文系统的页面名为“设备控制和数据访问”；其他版本可能显示“辅助功能”。菜单中的“启用键盘音量键”可重新请求并打开对应设置。未授权时菜单滑块仍可用。若键盘被设为标准功能键，请同时按 Fn 使用 F10/F11/F12 的音量功能。

只有当前显示器的软件音量处于 active 状态才接管音量键。切到内置扬声器等原生设备、暂停、睡眠或恢复失败时，音量键交给 macOS。程序仅请求系统媒体事件，过滤音量加、音量减和静音；普通按键不在监听范围内。

暂停和退出会恢复显示器原始播放音量。此版本尚未接入登录启动。

音频不保存、不上传。诊断模式仅输出状态、计数和音量幅度统计，没有音频文件；正常启动不写这些诊断文件。

## 项目维护

- `Sources/`：Swift 界面、媒体键与 HUD，Objective-C++ 音频引擎和纯策略。
- `Tests/`：自动策略测试及需显式运行的硬件验收工具。
- `docs/verification/`：原型阶段和后续验收记录；历史记录保留当时的 DisplayVolume 名称。
- `docs/ARCHITECTURE.md`：音频路径、线程和状态约束。
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

本地构建使用 ad-hoc 签名，重新编译可能再次出现音频授权提示。尚未使用 Developer ID 签名或公证；最低构建版本为 macOS 14.2，目前只在本机 macOS 27 验证。

## 构建

需要 Apple Command Line Tools 和 Swift 编译器。没有第三方依赖。

```sh
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

构建会自动运行状态策略、增益收敛、滑块同步、媒体事件路由和媒体键音量策略测试。

`Tests/audioctl.mm`、`Tests/integration.py` 和 `Tests/live_tone.py` 是显式运行的实机测试工具，不会随普通构建自动修改音频设置。integration.py 临时切换设备和采样率，结束时恢复原设置。

`Tests/volume_regression.py` 配合诊断模式和低幅度测试音验证从满音量调回、从零音量调高；结束时恢复到 50%。它验证真实 PCM 增益，不替代鼠标拖动验收。

`Tests/media_integration.py` 验证媒体键处理入口、HUD 和真实 PCM，临时切换到内置扬声器验证旁路，最终恢复原输出和原音量；真实物理按键另由用户验收。诊断启动可用 `--status-file 路径 --command-file 路径 --log 路径`；`--no-key-permission-prompt` 可跳过自动弹出媒体键授权提示，仍会检测已授予的权限。

产品改名后暂时沿用 `local.alexwu.DisplayVolume` Bundle Identifier，继续读取同一份设备音量设置；首次在新路径打开或重新编译时，macOS 仍可能要求重新授权。公开发布前再确定正式 Bundle Identifier 并规划设置迁移。

## 下一步

继续完成真实睡眠唤醒和长时间运行验收，再接入登录启动。发布前完善失败恢复、权限引导、代码签名与公证，并测量实际额外延迟。

媒体键授权实现参考 Apple 的 [AXIsProcessTrustedWithOptions 文档](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)；事件监听使用 [CGEvent.tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))，媒体事件字段参照本机 Apple SDK 的 IOKit `ev_keymap.h` 与 `IOLLEvent.h`。
