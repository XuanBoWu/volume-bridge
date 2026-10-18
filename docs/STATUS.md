# 当前背景与进度

更新日期：2026-10-19。本文是跨会话进度入口；最新提交与未提交改动请以 `git log`、`git status` 为准。Agent 必须先阅读仓库根目录 `AGENTS.md`。

## 2026-10-19 开源准备

- 用户选择 MIT，保留原 Git 作者姓名/邮箱，要求默认英文 README 并在开头提供中文版链接；不接入 GitHub macOS CI。本轮只准备和提交本地仓库，不创建远程、不推送、不打 tag。
- 已将此前图标、原生面板、日志、设备选择、提示音与媒体键修复整理为功能提交 `3cb2631`（隐私整理后的 ID）。代码仍为 0.2.3 / build 10；本轮没有修改运行逻辑或安装应用。
- 已扫描当前待公开文件与 main 历史，未发现所检查的私钥/常见 Token/凭据 URL；发现并脱敏机器路径、设备 UUID 和本地证书指纹，保留统计、版本和用户验收范围。原始历史与工作区备份位于忽略的 `work/open-source-prep-20261019/`，本地应用自动 checkpoint refs 与 reflog 不公开、不修改；不使用镜像推送。历史整理保留作者/提交者身份、日期和提交信息，但改变哈希。
- 新增 MIT、英文 README 与中文版、CONTRIBUTING、SECURITY、THIRD_PARTY_NOTICES、Issue/PR 模板；旧长 README 的开发资料仍由架构、测试、状态与交接文档保留。安全文档要求未来 GitHub 配置时启用私密漏洞报告，当前没有可用的仓库设置入口。
- 构建增加 `VB_SIGN_IDENTITY=-` 显式 ad-hoc 模式，跳过维护者钥匙串；可选签名初始化依赖 OpenSSL 3 已写清，普通构建不依赖它。补充忽略证书/私钥、DMG 和描述文件规则。
- 验证结果：准备前本地固定签名统一检查通过；显式 `VB_SIGN_IDENTITY=- zsh scripts/check.sh` 全部通过；JSON、文档本地链接、空白检查通过，未添加 workflow；全新独立克隆验证通过：无旧 build/work、无共享 Git object alternates，仅系统 PATH、Python 3.9.6 和 Apple Command Line Tools，使用不可用钥匙串路径仍完成全部 ad-hoc 检查；未安装或启动检查产物。只执行离线验证，未变更安装版、音频设备或权限。
- 验收摘要：`docs/verification/开源准备检查.json`；克隆验证后的收尾仅更新文档和验收结果，编译/测试/资源输入与已验证克隆一致。功能和开源准备分别提交，未添加 agent/AI 或 co-author 尾注。
- 下一步：用户确定 GitHub 所有者/仓库名并授权后发布 main；Developer ID/公证和预编译公开包另行安排。更多系统/设备、真实睡眠和长期稳定性待验收。详见 `docs/OPEN_SOURCE.md`。

## 用户目标与阶段

用户希望控制带音响的外接显示器音量，尤其是系统音量键无法调节的 HDMI/DisplayPort 输出。已完成：

- 技术验证、菜单栏原型、滑块修复、自动恢复和媒体键/HUD。
- 用户决定以音桥（VolumeBridge）长期维护，放在 `<project-root>`，使用 Git，并要求本地化与完整 Agent 交接。
- 2026-10-09 用户与 Agent 逐轮设计并选定了应用图标，已接入构建。

目前阶段是本机可用原型转为长期项目，尚未进入公开发布。仓库不依赖共享聊天链接才能继续开发；历史原型源码仍保留，但本仓库是后续唯一源码入口。

## 源码、产物与运行状态

| 项目 | 当前检查点 |
| --- | --- |
| 源码 | 0.2.3，构建号 10；统一检查通过，已安装 |
| Git | `main`，本机管理，无远程；历史隐私整理后迁移基线 `a0507ab`、功能集成 `3cb2631`；开源准备已整理为独立提交，全部验证通过；当前状态以 git status 为准 |
| 应用 | `/Applications/VolumeBridge.app` 为 0.2.3 / build 10，诊断测试后正常启动，当前单一运行进程；`build/VolumeBridge.app` 亦为 build 10，但本轮显式 ad-hoc 检查包未安装/启动 |
| 本机测试包 | `build/VolumeBridge-0.2.3-arm64.dmg` 为 2026-10-12 产物，尚不含 10-18 媒体键修复和提示音；需要时重新打包；本地自签名，未公证 |
| 界面名称 | 简体中文「音桥」，英文「VolumeBridge」 |
| 应用图标 | 金门大桥侧视图，晴空国际橙；`design/icon/icon.py` 生成 `Resources/AppIcon.icns`，详见 `docs/ICON.md` |
| Bundle ID / 设置域 | `local.alexwu.DisplayVolume`，保留旧设备音量设置 |
| 当前运行的版本 | `/Applications/VolumeBridge.app`，0.2.3 / 构建号 10；包含目标音量/设备列表及切回输出后的键盘监听修复；结束诊断后无参数正常启动、active、媒体键 ready，本地签名身份保持不变 |
| 最低构建目标 | macOS 14.2、默认 arm64；实机兼容性仅验证本机 macOS 27 |
| 发布状态 | 本地自签名；未接登录启动，未做 Developer ID 签名、公证、远程或公开发布 |

2026-10-08 交接时运行的原版应用路径为 `<legacy-workspace>/outputs/DisplayVolume.app`，旧版副本和开发构建副本已于 2026-10-11 移到废纸篓 `~/.Trash/VolumeBridge-legacy-20261011/`，未删除。开发目录中的 `build/VolumeBridge.app` 仍可由统一检查重新生成；生成后若不希望它出现在 Launchpad，应不要直接打开它，并在安装版使用期间保持它未注册。进程状态只是快照，后续应重新查询 `ps -axo pid,command`，不要使用历史 PID。启动新应用前先确认旧版已正常退出，不并行捕获或接管媒体键。

## 已完成与证据

| 范围 | 结论与证据 |
| --- | --- |
| 技术路径 | Core Audio Process Tap → 私有 Aggregate → 软件增益 → 同一显示器输出可行，真实 PCM 与用户听感均验证 |
| 音量和静音 | 用户确认增益变化与静音正常，无回声、爆音或断续；静音输入非零、输出为零见有效音频记录 |
| 滑块缺陷 | 用户曾发现到 100% 后拖不回/跳回；已修复旧快照覆写拖动/待确认值的问题，策略与真实 PCM 回归通过，用户确认正常 |
| 自动恢复 | 默认输出切换、原生旁路、采样率 48→44.1→48 kHz、暂停/恢复、重建、模拟睡眠入口通过 |
| 真实拔插 | 用户确认显示器拔插无问题；来自用户验收，不是脚本模拟 |
| 媒体键/HUD | 处理入口与真实 PCM 检查通过；用户已授权，并确认物理加减、两次静音、长按、浮层正常 |
| 项目迁移 | Projects 独立目录、构建脚本、Git 忽略、本机初始提交、历史证据整理完成 |
| i18n/l10n | 44 项 UI 资源、应用名、授权说明、无障碍描述、区域百分比；英文/简体中文/法语偏好下的英文回退运行检查通过 |
| 应用图标 | 用户逐轮选定造型和配色，并确认小尺寸方向；`.icns` 含 16–1024 px 共 10 个尺寸，16/32/64 px 为专用简化版本；统一检查加入图标检查；macOS 27 的系统图标快照显示正确、未被套灰色底框 |
| 本地日志 | 默认写入 `~/Library/Logs/VolumeBridge/`；JSONL 关键事件、1 MiB 文件轮转、12 MiB 总上限、14 天保留和 6 小时清理已接入；实时 IOProc 不写日志 |
| 音量提示音 | 键盘加/减和滑块松手后播放系统音量音，按平方曲线缩放；正常按键立即发声，仅约 20 ms 折叠同批重复事件；静音、0%、非 active 静默；独立队列播放，不进入 Tap/DSP。用户确认声音来自显示器且响度跟随音量，但初版 120 ms 合并导致连按节奏拖沓；已改为立即播放并把请求提前到界面刷新前，待复测 |
| UI | 原生 macOS Popover 主面板已接入并安装；当前迭代加入真实输出设备选择、跟随系统输出/固定设备模式和显式设为系统输出操作；使用系统控件、系统强调色和语义状态色，不使用品牌橙 |
| 文档 | AGENTS、背景进度、架构、决策、本地化、图标、测试指南、路线图和版本记录齐备 |

原始记录目录 `docs/verification/`：

- `设备切换测试.json`：设备切换、格式与生命周期。
- `有效音频与退出测试.json`、`最终构建状态.json`：实际输入/输出与正常退出；最终构建短时 3,107 次回调，无记录到的 mismatch / 过载通知。
- `满音量调回测试.json`：100→60→20→100→0→50→100→35→50 的真实增益回归。
- `媒体键处理与HUD测试.json`：直接调用应用处理入口、HUD、PCM 和旁路，不向系统注入按键。
- `用户验收与媒体键运行状态.json`：用户真实拔插、滑块、物理按键验收；当时记录 146 次物理媒体键操作。
- `项目迁移检查.json`：0.2.1 迁移离线检查，不能当作新版实机验收。
- `本地化与交接检查.json`：0.2.2 构建、资源与语言回退检查，未启动音频。
- `应用图标集成检查.json`：0.2.3 图标生成、打包、自动检查与系统图标快照，未启动应用。
- `DMG打包检查.json`：0.2.3 本机 DMG、统一离线检查、镜像校验与只读挂载内容验证，未安装或启动应用。
- `音量提示音接入检查.json`：保留 build 7 / 120 ms 初版的历史记录，当时未记录用户听感；后续试听和修正见下文。
- `设备选择与运行版本复核.json`：build 9 设备选择修复与离线回归。**后续发现默认日志混入离线模拟事件，内含 build 8 播放次数/延迟推断已撤回**；保留历史原始计数并附更正，不能当作实机证据。
- `切换输出后键盘监听恢复.json`：build 10 独立诊断、6 轮真实设备切换、系统实际 Tap 替换、用户物理按键确认、测试日志隔离与正常启动。

上述统计是短时记录，不是长期质量保证；历史 JSON 的设备 ID、音量、PID 不应成为运行参数。

## 本次检查范围（0.2.3）

- `zsh scripts/check.sh` 通过：应用编译、本地签名校验、设备/增益策略、滑块同步、媒体事件路由、媒体音量策略、控制器读取隔离、设备选择 HAL 替身回归、本地日志轮转、音量提示音策略与回退解码、应用图标检查、资源键与占位符、打包资源对照、三组语言/区域运行检查，以及 Python 语法检查（含 `design/`）。`git diff --check` 通过。提示音检查不播放声音。
- 第一轮体验优化已接入并安装：菜单栏图标按 active、静音、暂停、等待和错误状态变化，菜单新增打开日志目录入口；安装后启动日志再次确认 `active` 和媒体键 event tap ready。
- Popover 主面板已重新整理为原生控制面板结构；已移除左右加减按钮，加入真实输出设备下拉、跟随系统输出/固定设备目标、等待目标成为系统输出状态和显式设为系统输出动作。已安装并启动验证 Mi Monitor 的 active 链路和媒体键监听；未改变实时音频处理线程。
- 图标检查做过反例：App 中缺少 `AppIcon.icns` 时 `scripts/check-icon.sh` 会报错退出。
- `scripts/build-icon.sh` 在本机重复生成，`.icns` 与设计定稿时的产物逐字节一致。
- `swift scripts/app-icon-snapshot.swift build/VolumeBridge.app …` 导出系统实际显示的图标：显示新图标，没有被套灰色底框；64 px 取用专用版本。

本次加入本地日志层和日志轮转测试；日志不进入实时音频回调，也不保存音频。随后已退出旧安装版，替换为本地自签名构建并启动一次；实际日志记录了 `runtime.start`、媒体键权限请求、音频控制器启动、显示器切换和 `active` 状态。启动没有新增并行进程；未执行真实睡眠。

新应用的实际菜单布局、中英文系统授权窗口，以及新图标在 Finder、系统设置、权限弹窗中的显示，都尚未验收；启动已进入 `active`，但完整音频长时间运行和物理按键回归仍需安排。历史音频和物理按键验收属于 0.2.0；不可据此宣称 0.2.3 已完成同样的完整实机验收。音量提示音已通过离线策略、合并和回退解码检查；用户已确认初版声音来源和响度，最终 build 8 的连按节奏、滑块松手提示仍需验收。build 9 的设备选择修复已随 build 10 安装；固定/跟随输出切换已实测，真实拔插和更多设备仍待验证。

## DMG 打包（2026-10-09）

新增 `scripts/build-dmg.sh`，按当前未提交的 0.2.3 工作区编译并运行完整统一检查，生成 arm64 本机测试包。应用内资源与菜单文案、音频 DSP 和路由未改，源码版本仍为 0.2.3 / 构建号 6。

本次 `zsh scripts/build-dmg.sh` 通过：统一检查、镜像校验、只读挂载后的应用签名、全部包内文件与构建应用一致、原 Bundle ID 和 Applications 快捷入口；验证后已卸载镜像并清理暂存目录。`zsh -n scripts/build-dmg.sh` 和 `git diff --check` 通过。具体产物大小、SHA-256 及机器信息见 `docs/verification/DMG打包检查.json`。

DMG 构建本身没有安装或启动应用；随后进行的安装验收退出了旧包、把本地自签名构建复制到 `/Applications` 并启动一次。启动日志和 `active` 状态已确认，音频捕获链路未做长时间声学验收。本包未做 Developer ID 签名、公证、Gatekeeper 验收或其他机器兼容性验收。

## 未完成与后续顺序

1. build 10 已安装，固定/跟随模式共 6 轮实际切换及物理音量键已确认；下一步继续验收 0.2.3：检查新 Popover 的设备下拉、跟随/固定设备切换、设为系统输出、滑块、按钮、HUD、权限、旧设备音量设置承接，以及新图标在权限弹窗、系统设置隐私列表和 Finder 中的显示。需要新授权时按系统提示允许；切换应用语言后要重新启动。同时验收音量提示音：不同百分比响度、长按节奏、静音和切换设备时是否残留；步骤见 `docs/TESTING.md`。
2. 真实睡眠/唤醒：**用户已明确留待后续验证**。实现和模拟入口已具备，不应再次自动发起睡眠。
3. 长时间运行、权限撤销、音频服务重启、事件 Tap 超时、AirPods/其他组合、全屏/多桌面 HUD；测实际附加延迟与重建瞬间声学峰值。
4. 根据验收结果再接登录启动，并确定失败恢复/权限引导的下一轮需求。
5. 发布阶段再讨论正式 Bundle ID、设置迁移、签名公证、许可证、远程仓库与渠道；同时确认金门造型的商标/授权，并考虑 macOS 26+ 的深色/着色图标外观（见 `docs/ICON.md`）。

设备基线是 M1 Pro、macOS 27.0、Mi Monitor DisplayPort 双声道 48 kHz，无可写原生音量。设备 UID 用于持久化；AudioObjectID 只是临时编号。Intel、其他 macOS、其他显示器没有得到兼容性承诺。

## 应用副本清理（2026-10-11）

用户发现 macOS 上出现两个音桥图标。复核确认只有 `/Applications/VolumeBridge.app` 进程在运行；DMG 未挂载。为清理 LaunchServices 重复记录，旧版 `VolumeBridge.app`、`DisplayVolume.app`、备份版和可再生成的 `build/VolumeBridge.app` 已移到 `~/.Trash/VolumeBridge-legacy-20261011/`，随后注销旧路径并重启 Dock。清理后 LaunchServices 只保留 `/Applications/VolumeBridge.app`。没有删除文件、修改源码、改变音频设置或触发权限提示。若再次运行统一检查，开发构建 App 会重新出现；安装完成后不要从 `build/` 直接打开它。

## 媒体键权限排查（2026-10-11）

用户反馈安装版无法用键盘调节音量；重新在系统权限页关闭并打开 VolumeBridge 后立即恢复。复核安装包显示 `Signature=adhoc`，其 designated requirement 为当前构建的 `cdhash`，因此本地重编译、图标接入和重新打包都会改变 TCC 识别的代码身份。旧授权条目可能仍显示在列表中，但不再匹配当前包，导致 `AXIsProcessTrusted`/事件 Tap 初始化无法有效接管媒体键；重新授权会写入匹配当前 `cdhash` 的记录。音频链路和媒体键策略本身未改，恢复后键盘加减、静音继续正常。正式发布需稳定签名身份；开发阶段重签后应按此步骤重新授权。

## 本地签名（2026-10-11）

已运行 `zsh scripts/setup-local-signing.sh`，在登录钥匙串创建 `VolumeBridge Local Development` 自签名身份，有效期 3650 天。`build.sh` 默认显式使用这张证书；没有证书的环境才回退 ad-hoc。两次完整构建后的 designated requirement 均为：

`designated => identifier "local.alexwu.DisplayVolume" and certificate root = H"<local-certificate-sha1>"`

这证明本机普通重编译保持同一代码身份。该证书只适合本机开发，不能替代 Developer ID、公证或其他机器的 Gatekeeper 信任。

随后运行 `zsh scripts/build-dmg.sh` 通过统一检查、镜像校验、只读挂载后的本地签名验证、包内容比较和卸载；当前含设备选择和新 Popover 的 DMG 为 675,019 bytes，SHA-256 为 `6d6086248c93bbe20e7ecce776405b0c3c3019861db1a3549999b8edaca3ab00`。

已在用户安排的窗口退出旧版并替换为本地自签名设备选择版；当前安装前的可恢复副本保留在 `~/.Trash/VolumeBridge-pre-ui-device-final-20261012-083759.app`，之前的 UI 修正版另保留在同一回收站。新包启动后日志确认 `Mi Monitor` 进入 `active`，媒体键 event tap ready，签名 designated requirement 为固定本地证书根；后续若删除或更换该证书，仍可能需要重新确认系统权限。

## 0.2.3 变更记录

### 2026-10-18 切换输出后键盘失效跟进（build 10）

- 用户报告切换设备再切回来仍无法用键盘调音量。本轮先保留现场日志、设备清单、音量和目标设置，再以原 build 8 做真实显示器 → 内置扬声器 → 显示器切换。音频恢复 active、缓存接管资格为真，但事件监听始终复用同一个 Tap ID；系统 enabled/ready 状态不能证明事件送达。具体 WindowServer 内部原因尚未确认，不能称为已定位系统内部缺陷。
- 修复媒体键监听生命周期：以 active 会话的 UID、设备 ID 和音频 generation 变化触发重新创建；曾进入非接管状态后切回同一会话也重新创建。稳定 active 不重复创建，旁路时透传，停止旧监听并作废旧代次已排队回调。新增 `media.volumePacket`、接收/透传/按下计数和监听代次，方便区分事件未到与事件被透传。
- 新增 `Tests/MediaKeyLifecycle/main.swift`，注入监听替身执行真实 MediaKeys 类，覆盖仍报告 valid/enabled 的旧监听、同设备恢复、快切代次变化、设备 ID 变化和旧回调作废。`zsh scripts/check.sh` 全部通过，`git diff --check` 通过。
- 固定本地签名 requirement 比较一致后正常退出 build 8，旧包保留于 `~/.Trash/VolumeBridge-before-switch-key-fix-20261018-234256.app`，安装 build 10。实际执行固定/跟随各 3 轮切走、切回；每次切回系统 CGEventTap ID 均更换，最终仅一个有效已启用监听；应用处理入口的 12 次加减和 HUD 正常，mismatch/overload 为零。未向原生输出发送音量键或修改硬件音量/采样率。
- 自动切换测试结束已恢复原输出、目标模式、93.75% 和未静音；随后用户使用物理按键并明确答复“现在正常”。独立日志记录 96 个音量包、48 次接管按下，HUD 总计 60 次（包括 12 次处理入口测试）；没有 timeout 禁用或提示音播放失败。用户最后自行选到 68.75%，正常重启后继续保留，未把它改回自动测试前值。单次运行 PCM 幅度统计与当前平方增益一致，但未做受控测试音的完整回归。
- 本次还发现旧 Feedback/DeviceSelection 测试会自动启动默认日志，污染运行文件。现已将这些测试及新生命周期测试隔离到独立临时目录；实际重复运行三个测试，默认日志 SHA-256 前后一致。此前 build 8 的 113 次播放/39 ms 推断已撤回，在历史 JSON 附注更正；这轮使用独立诊断日志，用户按键与测试入口分别统计。
- 结束诊断后已正常退出并无参数启动 `/Applications/VolumeBridge.app`，默认受轮转管理的日志记录 build 10、active 和媒体键 ready，单一进程；没有遗留测试播放器、没有真实睡眠或录音。原始材料位于忽略的 `work/device-key-switch-20261018/`，摘要见 `docs/verification/切换输出后键盘监听恢复.json`。
- 长时间物理拔插、真实睡眠/唤醒、其他设备与系统仍待后续安排；这次的物理确认不能替代这些范围。未提交或暂存；建议本次修复提交信息：`fix: rebind media keys when audio control resumes`。

### 2026-10-18 提交前检查发现的设备选择修复（build 9，历史阶段，现已随 build 10 安装）

- 固定目标设备尚未成为系统输出时，原等待分支先覆写 `_desired` 并返回，导致随后跳过 UID 音量恢复。已将目标音量恢复放到等待判断之前；同 UID 配置重建继续保留音量与静音，无历史记录时使用 50%。
- 输出列表原用引擎的单输出/无输入流条件筛选，漏掉带麦克风的耳机等设备。现在按真实输出流判断可见性、汇总输出声道数；双向和多流设备可以选择，但软件接管仍限原有支持格式与拓扑。
- 新增 `Tests/DeviceSelection/main.mm`，替换 HAL 调用并运行真实控制器协调和枚举方法。先确认旧逻辑失败，再验证固定 B 等待/成为默认时使用 B 的 10%（A 为 80%）、未知目标 50%、目标断开重连、同 UID 改设备 ID 保留静音、跟随系统，以及双向/多流/纯输入/断开/私有设备的列表与接管资格。测试保持暂停、不启动引擎、不写用户设置，已接入统一入口。
- `zsh scripts/check.sh` 全部通过；追加原生旁路断言后的设备选择专项检查通过；`git diff --check` 通过。源码与构建包为 0.2.3 / build 9，固定本地签名校验通过，designated requirement 与安装版一致。
- 本轮没有重启或替换 `/Applications/VolumeBridge.app`，现场确认仍为 build 8、单一进程。修正旧交接的 build 7 描述，并保留 build 7 历史验收 JSON；旧摘要 `docs/verification/设备选择与运行版本复核.json` 曾从共享默认日志推断 build 8 的播放次数/延迟；后续发现混入离线测试记录，该推断已撤回并在 JSON 中更正，不能作为实机证据。
- 尚缺 build 9 安装后真实设备切换与拔插回归；最终提示音节奏和滑块松手听感仍待确认。未改变系统输出、采样率或硬件音量，未播放测试声音，未发起真实睡眠。该阶段的待安装事项已由随后 build 10 集成与切换测试推进，剩余范围见上节。
- 用户本轮授权修复，未授权提交；全部改动继续保留工作区。建议将此修复作为 `fix: restore target volume and include all output devices` 独立提交。

### 2026-10-18 音量提示音

- 用户要求调节音量时像原生方案一样有能体现音量大小的提示音。实现为：键盘音量加/减在队列确认后播放，滑块只在松手且后台确认后响一次；静音键、0%、暂停、旁路、等待、睡眠、错误、无目标设备和设备 UID 不一致时保持安静。
- 声音优先使用系统自带的 `volume.aiff`，缺失时使用内存合成的短 WAV 回退；没有新增资源或第三方依赖。`NSSound` 以目标设备 UID 播放，`volume` 设为 `(percent/100)²`，与 DSP 同曲线且只应用一次，因为本进程已被 Tap 排除，不会进入捕获链路。
- 播放/停止在独立 `local.displayvolume.feedback` 队列串行执行；系统音源在启动时预载，设备 UID 不变时不重复设置播放设备。正常按键立即发声，仅用约 20 ms 窗口折叠同批重复事件；每次读取最新音量并重启声音。提示音请求已提前到 `refresh()`/HUD/诊断写入之前，避免连按时主线程 UI 工作把声音越推越后；日志加入 `latencyMs`（按键到播放）。静音、切换设备、暂停和退出会取消待播放项并停止当前声音。未在实时 IOProc、媒体事件 Tap 或设备枚举路径增加工作。
- 新增 `Sources/VolumeFeedback.swift`、`Sources/VolumeFeedbackPolicy.swift`、`Tests/Feedback/main.swift`；`Sources/main.swift` 接入键盘、滑块和取消入口；`build.sh`、`scripts/check.sh` 纳入测试；`Info.plist` 构建号升到 7；同步更新 AGENTS、README、CHANGELOG、ARCHITECTURE、DECISIONS、TESTING、LOGGING、ROADMAP。
- `zsh scripts/check.sh` 与 `git diff --check` 通过，输出包含 `PASS volume feedback: square gain, silent states, latest-value coalescing, mute/device cancellation and fallback decoding; no sound played`。
- 已正常退出旧版并安装为 `/Applications/VolumeBridge.app`（0.2.3 / build 7），旧包备份在 `~/.Trash/VolumeBridge-before-feedback-20261018-184539.app`。安装版以诊断参数启动后进入 active，经应用处理入口和用户物理按键共记录 47 次 `feedback.played`（25–93.75%），没有 `feedback.playFailed` / `soundUnavailable`；正常启动后再次进入 active 并记录 10 次成功播放，观察段内没有 `tapDisabledByTimeout`。
- 用户试听后确认：提示音存在、由显示器音响发出、响度随音量变化，静音/暂停/切换设备表现可以；但**连按节奏拖沓、“感觉没对上”**。初版 120 ms 合并窗口按上次播放时间起算，加上请求排在 `refresh()`/HUD 之后，会把声音越推越后。
- 时序修正（build 8）：合并窗口缩到 20 ms，只折叠同批重复事件，人类按键不再被限速；提示音请求提前到界面刷新/HUD/诊断写入之前；系统音源启动时预载，设备 UID 不变时不重复设置；队列 QoS 提升到 `userInteractive`；`feedback.played` 增加按键到播放的 `latencyMs`，便于复测。滑块松手提示仍需单独确认。
- 可复用摘要见 `docs/verification/音量提示音接入检查.json`；原始日志在忽略的 `work/feedback-20261018/`。

### 2026-10-18 重连后键盘失效修复

- 用户在真实复现现场确认：显示器断开较长时间后重连，滑块可调节、键盘失效。旧日志显示重连已进入 `active`，随后媒体事件监听多次收到 `tapDisabledByTimeout`；旧进程采样显示主线程每 0.5 秒同步枚举所有音频设备，键盘回调内还同步查询 Core Audio。系统 Tap 延迟数据出现数百毫秒乃至秒级等待。
- 修复：设备列表由独立后台串行队列维护缓存（约 2 秒刷新），UI 和媒体键资格查询只读快照；媒体事件 Tap 迁移至独立 `VolumeBridge.MediaKeys` 线程，回调先返回路由结果，再异步执行音量/HUD/UI 操作；生命周期队列执行时仍查询实时默认输出并核对 UID。停止监听时立即禁用并结束 RunLoop，通过代次丢弃遗留操作。实时 DSP、增益和用户设备选择不变。
- 新增 `Tests/ControllerReads/main.mm` 并加入构建：用 HAL 函数替身断言设备列表及媒体键资格读操作不触发任何同步 HAL 查询。`zsh scripts/check.sh`、`git diff --check` 通过。
- 已替换 `/Applications/VolumeBridge.app`，故障旧包保留于 `~/.Trash/VolumeBridge-before-reconnect-fix-20261018-181958.app`；最终安装前副本位于 `~/.Trash/VolumeBridge-before-final-reconnect-fix-20261018-182546.app`。固定签名 requirement 保持一致，最终正常启动进入 active、媒体键 ready，单一进程运行。
- 验证分为两轮：先移除同步 HAL 后用户确认恢复，诊断运行段有 52 次物理按键、非零 PCM 幅度、mismatch/overload 为零；但用户重启后又捕获一次超时，因而继续加入独立监听线程。最终线程隔离版用户再次确认“仍然正常”，最终正常启动段已记录 28 次物理按键、零超时禁用。启动时有一条 `tapDisabledByUserInput`（4294967295）记录，已重新启用，不应与本次故障的 timeout（4294967294）混淆。
- 新进程采样的主线程不再包含 Core Audio 查询；慢设备枚举出现在独立后台队列，媒体监听有独立 RunLoop。系统 Tap 延迟统计读数仍波动，不用该数值宣称回调耗时改善；不能以短时通过宣称后续所有长时间拔插/睡眠场景均已解决。长时间断开再重连应继续观察，不主动安排真实睡眠。
- 工具未改变系统输出、采样率或硬件音量；用户按键自行改变的软件音量保留。原始采样、日志、状态统计位于忽略的 `work/reconnect-20261018/`，可复用摘要见 `docs/verification/重连后媒体键超时修复.json`。
- 重连修复安装时源码为 0.2.3 / build 6，未提交；提示音和时序修正版为 build 8，本次设备选择修复后的工作区为 build 9。上文 DMG 为 2026-10-12 产物，**尚不包含重连修复或提示音**；需要新安装包时重新运行 `zsh scripts/build-dmg.sh`。建议本次提交信息：`fix: keep audio device queries off the media key event path`。

2026-10-19 用户授权整理本地提交，为开源准备；以下功能与测试已通过统一检查，并整理为功能集成提交。相关文件：

- 修改：`Info.plist`、`build.sh`、`scripts/check.sh`，以及文档。
- 新增：`Resources/AppIcon.icns`、`design/icon/`、`scripts/build-icon.sh`、`scripts/check-icon.sh`、`scripts/app-icon-snapshot.swift`、`scripts/setup-local-signing.sh`、`docs/ICON.md`、`docs/verification/应用图标集成检查.json`。
- 日志新增：`Sources/Logging.h`、`Sources/Logging.mm`、`Sources/Logging.swift`、`Tests/Logging/main.mm`、`docs/LOGGING.md`。
- 提示音新增：`Sources/VolumeFeedback.swift`、`Sources/VolumeFeedbackPolicy.swift`、`Tests/Feedback/main.swift`；更新 `Sources/main.swift`、构建检查和文档。
- UI 新增：`Sources/ControlPopover.swift`、`docs/UI-DESIGN.md`；更新 `Sources/main.swift`、`Sources/AudioController.h/.mm`、英文/简体中文资源和构建脚本，加入输出设备选择与显式默认输出切换，未改变实时音频回调。
- DMG 任务新增：`scripts/build-dmg.sh`、`docs/verification/DMG打包检查.json`；同步更新打包说明与交接文档。未获提交授权，继续保留在工作区；DMG 和应用产物留在忽略的 `build/`。建议另一个提交信息：`build: add verified local DMG packaging`。

功能集成提交信息：`feat: add native controls and resilient volume handling`。本次开源准备另以独立提交记录；未创建远程、推送或打 tag。历史小节中的“未提交”描述保留为各阶段现场记录，当前状态以 Git 为准。

## 更新方法

继续工作后更新本文中的源码/运行版本、检查结果、验收证据与未完成项；完整测试方法见 TESTING，稳定技术理由见 DECISIONS，图标相关见 ICON。不要删掉未验证项来制造「已完成」状态。提交后以 `git log` 定位代码，无须把当前提交哈希写进其自身文件。
