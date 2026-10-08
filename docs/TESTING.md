# 构建、测试与验收指南

所有命令在项目根目录运行。普通构建与真实硬件测试是两个独立步骤；没有必要为了文档或文案修改重复切换音频设备。当前验收证据和待测范围见 STATUS.md。

## 日常离线检查

```sh
zsh scripts/check.sh
git diff --check
```

统一入口依次编译应用、校验 ad-hoc 签名，运行以下检查：

| 检查 | 保护行为 |
| --- | --- |
| Tests/policy.cpp | 支持设备条件、恢复决策、增益平滑与端点 |
| Tests/Slider/main.swift | 拖动/待确认期间旧快照不覆盖值，确认后同步、切换设备与旁路 |
| Tests/MediaKeys/main.swift | 解析系统媒体事件、按下释放、重复与静音去重、旁路透传 |
| Tests/media_volume.cpp | 连续增量、上下限、细调、解除静音 |
| scripts/check-localizations.py | 资源键/占位符/引用/打包一致性 |
| Tests/Localization/main.swift | en / zh-Hans / 英文回退、区域百分比、元数据与后端初始说明 |
| Python AST 解析 | 实机工具和检查脚本语法 |

`zsh build.sh` 编译并运行前四类策略检查，产物 `build/VolumeBridge.app`。本地化检查由统一入口补充；单独运行 `zsh scripts/test-localizations.sh` 前应先构建 AudioController.o 和主应用。默认 arm64/macOS 14.2；`VB_BUILD_DIR` 和 `VB_ARCH` 可改变构建设置，但不代表对应平台已实测。

上述命令不启动系统音频捕获、不请求媒体键权限、不播放声音、不切换设备或硬件音量。LocalizationTests 仅读取控制器初始化快照。

## 新路径首次启动与本地化验收

先正常退出原版 DisplayVolume，再运行 `open build/VolumeBridge.app`，不能同时运行两版。首次启动按系统提示授予捕获/音量键权限，检查状态进入 active、设备与保存的音量正确。同 Bundle ID 并不保证签名或路径变化后仍免授权。

分别使用简体中文和英文应用语言，重新启动后检查名称、完整菜单/状态文案、滑块、HUD、无障碍描述与可见范围；需要系统再次授权时检查说明语言。物理按键测试音量减、加、静音两次和长按；确认未抢焦点。新路径 0.2.2 尚未完成这些步骤。

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

## 验收记录要求

每次写清日期、代码版本/提交、机器/系统/设备、输入与预期、自动与人工范围、结果、结束时状态与未完成项。可复用摘要放 `docs/verification/`；运行日志/临时命令留在忽略目录，不存储音频捕获。

策略检查不等于物理按键；处理入口加 PCM 不等于用户拖动；模拟睡眠不等于真实睡眠；零过载通知不等于已证明零断续或延迟。真实睡眠/唤醒已由用户留待后续，不要自动让机器睡眠。
