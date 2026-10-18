# 构建、测试与验收指南

所有命令在项目根目录运行。普通构建与真实硬件测试是两个独立步骤；没有必要为了文档或文案修改重复切换音频设备。当前验收证据和待测范围见 STATUS.md。

## 日常离线检查

```sh
zsh scripts/check.sh
git diff --check
```

统一入口依次编译应用、校验签名，运行以下检查：

| 检查 | 保护行为 |
| --- | --- |
| Tests/policy.cpp | 支持设备条件、恢复决策、增益平滑与端点 |
| Tests/Slider/main.swift | 拖动/待确认期间旧快照不覆盖值，确认后同步、切换设备与旁路 |
| Tests/MediaKeys/main.swift | 解析系统媒体事件、按下释放、重复与静音去重、旁路透传 |
| Tests/MediaKeyLifecycle/main.swift | 用监听替身运行真实 MediaKeys 生命周期：切回同设备、UID/设备 ID/音频代次变化时替换仍报告正常的旧监听；稳定会话不重建、原生旁路不阻断，旧代次回调作废；不创建系统 Tap 或发送按键 |
| Tests/ControllerReads/main.mm | 用 HAL 函数替身保证 UI 设备列表与媒体键资格查询只读缓存，不同步访问音频服务 |
| Tests/DeviceSelection/main.mm | 用 HAL 替身运行真实控制器协调逻辑：固定目标等待前恢复独立音量、断开重连、同 UID 重建保留静音，以及双向/多流设备可见但不扩大接管范围；不启动引擎、不写用户设置 |
| Tests/media_volume.cpp | 连续增量、上下限、细调、解除静音 |
| Tests/Logging/main.mm | JSONL 输出、单文件轮转和总容量上限 |
| Tests/Feedback/main.swift | 提示音平方增益、静音/非 active 静默、连续调整合并、设备与静音取消、节流间隔和回退 WAV 解码（不播放声音） |
| scripts/check-icon.sh | Info.plist 声明 `CFBundleIconFile`，打包的 `AppIcon.icns` 与 `Resources/` 一致，10 个尺寸（16–1024 px）齐全 |
| scripts/check-localizations.py | 资源键/占位符/引用/打包一致性 |
| Tests/Localization/main.swift | en / zh-Hans / 英文回退、区域百分比、元数据与后端初始说明 |
| Python AST 解析 | 实机工具、检查脚本和 `design/` 下图标生成器的语法 |

`zsh build.sh` 编译并运行策略与日志检查，产物 `build/VolumeBridge.app`；结束时会 `touch` App，便于 Finder 刷新图标缓存。图标与本地化检查由统一入口补充；单独运行 `zsh scripts/test-localizations.sh` 前应先构建 AudioController.o、Logging.o 和主应用。默认 arm64/macOS 14.2；`VB_BUILD_DIR` 和 `VB_ARCH` 可改变构建设置，但不代表对应平台已实测。

上述命令不启动系统音频捕获、不请求媒体键权限、不播放声音、不切换设备或硬件音量。LocalizationTests 仅读取控制器初始化快照。

Feedback、DeviceSelection、MediaKeyLifecycle 使用各自唯一的临时日志目录，结束关闭并清理；不得让日志自动写入日常运行文件。历史上模拟播放/设备事件曾污染默认日志，旧记录须按进程和独立诊断文件核实，不能直接当作安装版的播放或按键统计。

普通启动会写入 `~/Library/Logs/VolumeBridge/volume-bridge.log`，但不会写入音频内容。日志自动按大小轮转，并在启动时及每 6 小时清理旧文件；日志字段和收集方式见 [LOGGING.md](LOGGING.md)。

## 新路径首次启动与本地化验收

首次在本机构建前运行 `zsh scripts/setup-local-signing.sh`，让构建使用固定的 `VolumeBridge Local Development` 身份；没有该身份时才回退 ad-hoc。先正常退出原版 DisplayVolume，再运行 `open build/VolumeBridge.app`，不能同时运行两版。首次启动按系统提示授予捕获/音量键权限，检查状态进入 active、设备与保存的音量正确。同 Bundle ID 并不保证签名或路径变化后仍免授权；删除或更换本地证书、Bundle ID 或权限配置后仍可能需要重新授权。

分别使用简体中文和英文应用语言，重新启动后检查名称、Popover/状态文案、滑块、按钮、HUD、无障碍描述与可见范围；需要系统再次授权时检查说明语言。物理按键测试音量减、加、静音两次和长按；确认未抢焦点。同时查看新图标在权限弹窗、系统设置隐私列表（如「设备控制和数据访问」）和 Finder 中的显示。新路径 0.2.3 的完整人工验收仍待用户安排。

## 音量提示音

提示音只在真实音量调整时播放，自动检查不发声。人工验收步骤：

1. 确认只有一个 VolumeBridge 进程，状态为 active，目标设备就是当前默认输出。
2. 在 25%、50%、100% 分别按一次音量加或减，应听到与系统调音量相同的短提示音，响度随百分比上升；0% 和静音键保持安静。
3. 长按音量键应连续、不重叠地发声，音量浮层与提示音同步；快速连按不应用旧音量播放。
4. 拖动滑块过程中保持安静，松手且后台确认后响一次；暂停、切到原生设备或等待目标设备时调整不应发声。
5. 静音、切换输出设备、暂停和退出时，不应残留未播放或正在播放的提示音。

提示音优先使用 `/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff`；文件缺失时使用内存合成回退。提示音由本进程直接播放，已被 Tap 排除，不会被再次衰减或录入捕获链路。

排查时看日志中的 `feedback.played`（debug，含 `uid`、`percent`、`gain`）、`feedback.playFailed` 和 `feedback.soundUnavailable`。听到声音但响度不随音量变化、或音量键正常而提示音不响，应分别记录为实机问题，不要用离线检查代替。测试结束恢复原音量；不要在自动化 PCM 测试期间预期绝对静音，因为调音量本身会发出提示音。

## 应用图标

`scripts/check-icon.sh` 已包含在统一检查中。另有两个显式工具：

```sh
zsh scripts/build-icon.sh
swift scripts/app-icon-snapshot.swift build/VolumeBridge.app build/icon-snapshot.png 512
```

- `build-icon.sh`：根据 `design/icon/icon.py` 重新生成图标。
  - 会覆盖 `Resources/AppIcon.icns`、`design/icon/*.svg` 和 `design/icon/preview.png`，中间文件放在 `build/icon/`。
  - 需要 Google Chrome 和 ImageMagick，会在后台短暂启动 headless Chrome，使用隔离的临时配置目录和 mock keychain。
  - 只在改图标时运行。
- `app-icon-snapshot.swift`：只读，导出 macOS（IconServices）为这个 App 实际显示的图标，不启动 App。可以用来确认图标被系统识别、没有被套灰色底框，以及小尺寸取用了哪个版本。
  - 必须传入存在的 App 路径；路径会被转换成绝对路径。
  - 导出结果只代表系统的图标渲染，不能替代 Finder、系统设置、权限弹窗里的人工查看。

设计约束、尺寸档和历史见 `docs/ICON.md`。

## DMG 打包检查

`zsh scripts/build-dmg.sh` 先执行统一离线检查，再将应用和 `/Applications` 快捷入口放入 UDZO 压缩只读镜像。文件名取自应用版本和 `VB_ARCH`，输出在 `VB_BUILD_DIR`（默认 `build/`）。

自动验证包括：`hdiutil verify`、只读挂载后的应用签名、挂载应用与构建应用的完整目录比较、Bundle ID 和 Applications 链接。验证结束卸载镜像，清理暂存目录并输出 SHA-256；不打开 Finder、不安装、不启动应用，不改变音频或权限。macOS 27 的 hdiutil 会输出弃用提示，目前命令仍可用；继续使用该入口以兼顾 macOS 14.2 构建环境。

DMG 验证不等于安装和启动验收，也不代表 Gatekeeper 接受、公证或其他机器兼容性。后续人工验收需双击镜像，拖入 Applications，先确认旧版已退出，再检查新路径启动和权限。

## 显式实机工具

准备工具和低幅度合成音：

```sh
zsh scripts/build-audioctl.sh
build/audioctl list
python3 scripts/make-test-tone.py work/test-tone.wav
```

`audioctl list` 只读；其他子命令能更改真实硬件。测试素材为 50 秒、48 kHz、16-bit 双声道 440 Hz，幅度约 0.02；生成不播放、不录音。

退出旧版后启动诊断模式：

```sh
mkdir -p work
open build/VolumeBridge.app --args \
  --status-file "$PWD/work/status.json" \
  --command-file "$PWD/work/command.json" \
  --log "$PWD/work/runtime.log"
```

可选 `--duration 秒数` 到时正常退出；`--no-key-permission-prompt` 只跳过自动请求媒体键权限，不替代音频捕获授权。正常启动不写诊断文件。协议通过不同 token 的 JSON 命令触发 volume/mute/unmute/pause/resume/retry/sleep/wake/media-key，调用应用入口，不向 macOS 注入按键；sleep/wake 也不会改变系统真正睡眠状态。

按所需范围选择工具，不依次盲跑：

```sh
python3 Tests/integration.py build/audioctl work/status.json \
  work/command.json work/device-results.json
python3 Tests/volume_regression.py work/status.json work/command.json \
  work/test-tone.wav work/volume-results.json
python3 Tests/media_integration.py build/audioctl work/status.json \
  work/command.json work/test-tone.wav work/media-results.json
python3 Tests/live_tone.py build/audioctl work/status.json \
  work/command.json work/test-tone.wav work/pcm-exit-results.json
```

| 工具 | 副作用与结束行为 |
| --- | --- |
| integration.py | 切换默认输出、临时降低内置音量、更改采样率、改应用音量和状态；finally 恢复硬件输出/系统效果输出/采样率/内置音量，应用留在暂停，软件百分比未完整恢复 |
| volume_regression.py | 播放合成音、连续调整软件音量；停止播放器，最终设置 50%，不恢复测试前百分比 |
| media_integration.py | 播放合成音、直接调用媒体键处理、暂停/恢复并切到内置输出；成功结束恢复原输出和软件音量/静音；失败路径仍需现场核对状态 |
| live_tone.py | 播放合成音、重建、采样率 44.1 kHz 及恢复、静音；最后 SIGTERM 正常退出应用。finally 停播放器并恢复采样率，不恢复运行状态/原软件百分比 |

工具假设本机有 BuiltInSpeakerDevice、可用显示器与对应格式，不能当成通用多设备测试框架。`live_tone.py` 要求只有一个 VolumeBridge 进程。运行前记录当前状态，运行后核对实际恢复结果；设备消失或中途失败时，finally 也可能无法完成全部恢复，不能仅凭代码存在 finally 宣称已恢复。

### 输出切换后音量键恢复

记录当前默认输出、系统效果输出、采样率、硬件音量、软件音量/静音和目标模式。分别在固定显示器和跟随系统两种模式下执行显示器 → 内置扬声器 → 显示器；固定模式切走时应为 waiting，跟随模式为 bypass，均不接管按键；切回后应恢复 active。

切回后核对 `media.audioSessionRebind`、新的 `media.eventTapReady.generation` 和诊断 `mediaKeyTapGeneration`，必要时通过只读 `CGGetEventTapList` 检查实际 Tap ID 已更换、旧监听已移除。单看 valid/enabled/ready 不能证明音量键事件仍会送达。稳定 active 期间连续按键或刷新不应反复创建监听。

随后分别验证应用 `media-key` 处理入口和真实物理音量键：诊断计数 `mediaKeyPackets` / `mediaKeyPresses` 及 `media.volumePacket` 能区分未收到事件、收到但透传、成功接管；`media-key` 命令直接调用处理入口，不增加真实事件计数，也不能充当物理按键验收。结束恢复测试前各项现场值，不发送原生设备的音量键以改变硬件音量，不主动进行真实睡眠。

## 验收记录要求

每次写清日期、代码版本/提交、机器/系统/设备、输入与预期、自动与人工范围、结果、结束时状态与未完成项。可复用摘要放 `docs/verification/`；运行日志/临时命令留在忽略目录，不存储音频捕获。

策略检查不等于物理按键；处理入口加 PCM 不等于用户拖动；模拟睡眠不等于真实睡眠；零过载通知不等于已证明零断续或延迟。真实睡眠/唤醒已由用户留待后续，不要自动让机器睡眠。
