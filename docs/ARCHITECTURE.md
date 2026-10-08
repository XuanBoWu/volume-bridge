# 架构与维护约束

音桥通过 Core Audio Process Tap 获取当前显示器播放的系统音频，以软件增益衰减后在该显示器输出。它不安装虚拟驱动，不依赖显示器 DDC，不改造 macOS 控制中心原生音量滑块。

## 音频路径

系统音频 → 排除本进程的设备级 Process Tap → 私有 Aggregate Device → IOProc 双声道 Float32 增益 → 物理显示器输出。

Tap 使用 mutedWhenTapped，避免处理期间原始音频与处理后音频重叠。物理输出作为 Aggregate 主时钟，Tap 开启漂移补偿。GUI 0–100% 映射为 `(percent / 100)²`；实际回调以约 4 ms 时间常数平滑，靠近目标后收敛到精确端点。

当前处理范围：HDMI / DisplayPort、无输入流、单输出流、双声道交错 Float32 PCM、无可写原生音量。其他设备旁路或标记不支持。

## 执行边界

- `Sources/AudioController.mm`：串行队列负责设备监听、恢复、音量记忆、资源创建销毁；音频回调只处理 PCM 和原子计数。
- `Sources/Policy.hpp`：设备条件、生命周期决策和增益收敛的纯策略。
- `Sources/MediaVolume.hpp`：基于队列中的最新音量累计按键调整，不从延迟的 UI 快照计算增量。
- `Sources/main.swift`：AppKit 主线程管理菜单栏、睡眠通知和退出。
- `Sources/VolumeSliderState.swift`：保留最新鼠标输入，防止旧快照重置正在拖动的滑块；后到达的键盘输入可接替待确认鼠标输入。
- `Sources/MediaKeys.swift` / `MediaKeyPolicy.swift`：仅订阅系统媒体事件，过滤音量三键；普通按键不进入处理。匹配按下和释放，去除静音重复切换。
- `Sources/VolumeHUD.swift`：不激活、不拦截鼠标的浮层，显示设备与音量，按键停止约 1.4 秒后隐藏。
- `Sources/Localization.swift` / `Resources/`：原生 Bundle 翻译与区域百分比；后端说明在生命周期队列查找文案，实时回调不读取资源。机器状态和诊断字段保持不变。

快照通过短时同步访问提供给 UI。媒体键先检查 active 和当前默认输出，再在串行队列内核对状态与 UID，避免切换设备后的旧事件改变新设备。

## 恢复与退出

设备变化事件合并约 200 ms，另外每 2 秒检查配置。原生设备、暂停、睡眠和不支持输出释放音频链路。启动失败使用 1、2、4、8、16、30 秒退避重试。

同一显示器重建时，旧 Tap 先保持静音保护，新链路成功后才释放旧 Tap。失败时保留保护。正常退出先停媒体事件监听和浮层，再释放音频资源，最后退出进程。程序退出或崩溃后软件衰减消失，恢复原始输出音量。

设备 UID 音量设置暂存在 `local.alexwu.DisplayVolume` 的 UserDefaults。产品改名不同时更改此域；正式发布时需确定命名、签名与设置迁移方案。

## 验证边界

短时测试覆盖真实 PCM、设备切换和格式重建，用户覆盖实际拔插和真实媒体键。模拟睡眠入口与真实睡眠验收不同；缓冲时长不等于完整播放延迟，过载计数为零也不能证明长时间完全无断续。详细记录见 `verification/` 和 STATUS.md，测试方法见 TESTING.md，历史修复原因见 DECISIONS.md。
