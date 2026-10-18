# 本地日志

VolumeBridge 默认把运行日志写到：

```text
~/Library/Logs/VolumeBridge/volume-bridge.log
```

日志是逐行 JSON（JSONL），每行包含时间、级别、事件名和可选字段。应用同时把同一事件镜像到 macOS 的统一日志，便于临时用 Console 查看。

## 保存和清理策略

- 单个文件超过 1 MiB 后轮转为 `.1`、`.2` 等历史文件。
- 默认最多保留 12 个文件，总大小不超过 12 MiB。
- 超过 14 天的轮转文件会删除。
- 应用启动时清理一次，运行期间每 6 小时自动清理一次。
- 日志目录权限为用户可读写，文件权限为用户可读写；不会上传或写入音频数据。
- `--log 路径` 用于显式诊断时把日志写到指定路径。该路径仍按 1 MiB 轮转，但不会由应用清理指定目录，避免误删用户指定位置的其他文件。

## 关键事件

日志会记录以下排查所需信息：

- 应用启动、退出、版本、Bundle ID、进程号、系统版本和运行路径；
- 音频控制器启动/停止、输出设备切换、设备 UID、格式、采样率、缓冲区、通道数；
- 链路状态变化：starting、active、recovering、waiting、bypass、paused、sleeping、error；
- Core Audio 创建、销毁、监听器、服务重启、缓冲格式不匹配和 overload；
- 自动重试的错误码、次数、下次重试间隔，以及是否仍有静音保护；
- 音频捕获和媒体键权限请求、权限状态变化、事件 Tap 创建/禁用/恢复；
- 音频会话恢复后的 `media.audioSessionRebind`（UID、设备 ID、音频代次）和 `media.eventTapReady.generation`（监听代次）；`media.volumePacket` 只记录音量三键的 down/repeat、接管资格 active 与 consumed，用来区分未收到事件和收到后透传；
- 静音、暂停、睡眠/唤醒、手动重建和退出等控制操作；
- 音量提示音的播放结果：`feedback.played`（设备 UID、百分比、实际增益）、`feedback.playFailed` 和 `feedback.soundUnavailable`。

连续滑块调整使用 debug 级别，媒体键和提示音明细也使用 debug 级别；这些记录仍受轮转和总容量限制。提示音日志只记录设备、百分比和增益，不保存音频。

诊断状态另外提供 `mediaKeyPackets`（当前进程收到的音量包）、`mediaKeyPassedPackets`（透传数）、`mediaKeyPresses`（接管的按下动作）和 `mediaKeyTapGeneration`。命令文件中的 `media-key` 是直接处理入口，不增加这些事件计数；计数不等于人工听感验收。

离线测试显式使用独立临时日志目录，不能共享默认运行文件。2026-10-18 发现旧测试会写入默认文件，之前的混合播放次数推断已在 STATUS 和相应验收记录中更正；不要用包含模拟 UID/事件的历史共享文件直接统计安装版行为。

实时 IOProc 不允许调用日志系统。它只维护回调、格式不匹配、采样数量和幅度统计原子计数，由生命周期队列和主线程异步写入日志。

## 现场收集

```sh
open ~/Library/Logs/VolumeBridge
tail -n 200 ~/Library/Logs/VolumeBridge/volume-bridge.log
```

收集问题时同时记录应用版本、macOS 版本、连接方式和复现时间。日志中的设备名称和 UID 只用于本机排查；不要把包含个人设备名称的日志公开到不必要的渠道。
