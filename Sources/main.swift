import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    let audio = DVAudioController()
    let mediaKeys = MediaKeys()
    let hud = VolumeHUD()
    var feedback: VolumeFeedback?
    var sliderFeedbackStartValue: Double?
    var pendingSliderFeedbackUID: String?
    let controls = ControlPopoverViewController()
    var item: NSStatusItem!
    let popover = NSPopover()
    var sliderState = VolumeSliderState()
    var volumeChangeSequence: UInt64 = 0
    var timer: Timer?
    var signalSources: [DispatchSourceSignal] = []
    var observers: [NSObjectProtocol] = []
    var finished = false
    var closing = false
    var lastCommand = ""
    let args = ProcessInfo.processInfo.arguments

    func argument(_ name: String) -> String? {
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let logPath = argument("--log")
        AppLog.start(overridePath: logPath)
        let info = Bundle.main.infoDictionary ?? [:]
        AppLog.info("runtime.start", [
            "bundleID": Bundle.main.bundleIdentifier ?? "",
            "version": info["CFBundleShortVersionString"] as? String ?? "",
            "build": info["CFBundleVersion"] as? String ?? "",
            "path": Bundle.main.bundlePath,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
        ])
        if let path = argument("--log") {
            freopen(path, "a", stderr)
            setbuf(stderr, nil)
        }

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: L10n.text("app.name"))
        item.button?.setAccessibilityLabel(L10n.text("app.name"))

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 430)
        popover.contentViewController = controls
        controls.loadViewIfNeeded()
        configureControls()

        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.audio.setSleeping(true)
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.audio.setSleeping(false)
        })
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in self?.quitApp() }
            source.resume()
            signalSources.append(source)
        }

        feedback = VolumeFeedback { [weak audio] in audio?.snapshot() ?? [:] }
        audio.start()
        mediaKeys.shouldHandle = { [weak audio] in audio?.canHandleMediaKeys() == true }
        mediaKeys.onKey = { [weak self] key, fine in self?.handleVolumeKey(key, fine: fine) }
        if !args.contains("--no-key-permission-prompt") { mediaKeys.requestPermission() }
        timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.processTestCommand()
            self?.mediaKeys.refreshPermission()
            self?.refresh()
        }
        RunLoop.main.add(timer!, forMode: .common)
        if let text = argument("--duration"), let seconds = Double(text), seconds > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in self?.quitApp() }
        }
        refresh()
        if args.contains("--show-popover") {
            DispatchQueue.main.async { [weak self] in self?.togglePopover() }
        }
    }

    private func configureControls() {
        controls.onVolumeChange = { [weak self] value in self?.setVolume(value) }
        controls.onTrackingChange = { [weak self] tracking in
            guard let self else { return }
            if tracking {
                self.feedback?.cancel()
                self.sliderFeedbackStartValue = self.sliderState.value
                self.sliderState.beginTracking()
            } else {
                self.sliderState.endTracking()
                if let start = self.sliderFeedbackStartValue, abs(start - self.sliderState.value) > 0.0001 {
                    self.pendingSliderFeedbackUID = self.sliderState.deviceUID
                }
                self.sliderFeedbackStartValue = nil
                self.refresh()
            }
        }
        controls.onMute = { [weak self] in self?.toggleMute() }
        controls.onPause = { [weak self] in self?.togglePause() }
        controls.onRetry = { [weak self] in self?.retry() }
        controls.onKeys = { [weak self] in self?.enableMediaKeys() }
        controls.onDeviceSelect = { [weak self] uid in self?.selectDevice(uid) }
        controls.onSetSystemOutput = { [weak self] in self?.setSelectedDeviceAsSystemOutput() }
        controls.onLogs = { [weak self] in self?.openLogs() }
        controls.onQuit = { [weak self] in self?.quitApp() }
    }

    func status() -> [String: Any] { audio.snapshot() }

    func refresh() {
        let snapshot = status()
        mediaKeys.synchronizeAudio(snapshot)
        let state = snapshot["state"] as? String ?? "stopped"
        let muted = (snapshot["muted"] as? NSNumber)?.boolValue ?? false
        let percent = (snapshot["volume"] as? NSNumber)?.doubleValue ?? 50
        let uid = snapshot["uid"] as? String ?? ""
        sliderState.refresh(volume: percent, uid: uid, enabled: state == "active")
        feedback?.synchronize()
        if let pendingUID = pendingSliderFeedbackUID {
            if pendingUID != uid || state != "active" {
                pendingSliderFeedbackUID = nil
            } else if !sliderState.isTracking && sliderState.pendingValue == nil {
                pendingSliderFeedbackUID = nil
                feedback?.request(forUID: uid)
            }
        }
        controls.update(
            snapshot: snapshot,
            mediaState: mediaKeys.state,
            sliderValue: sliderState.value,
            sliderEnabled: state == "active",
            muted: muted && sliderState.pendingValue == nil,
            devices: audio.availableOutputDevices()
        )
        if state != "active" { hud.hide() }
        item.button?.image = NSImage(systemSymbolName: statusItemSymbol(state: state, muted: muted), accessibilityDescription: L10n.text("app.name"))
        item.button?.toolTip = L10n.format("app.tooltip", L10n.text("app.name"), L10n.stateLabel(state), snapshot["name"] as? String ?? "")
        writeStatus(snapshot)
    }

    private func statusItemSymbol(state: String, muted: Bool) -> String {
        if state == "active" { return muted ? "speaker.slash.fill" : "speaker.wave.2.fill" }
        switch state {
        case "paused": return "pause.circle"
        case "sleeping": return "moon.zzz"
        case "error": return "exclamationmark.triangle"
        case "waiting", "starting", "recovering": return "ellipsis.circle"
        default: return "speaker.wave.2"
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        refresh()
        guard let button = item.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func writeStatus(_ snapshot: [String: Any]) {
        var diagnostic = snapshot
        diagnostic["mediaKeysState"] = mediaKeys.state
        diagnostic["mediaKeyPresses"] = mediaKeys.acceptedPresses
        diagnostic["mediaKeyPackets"] = mediaKeys.receivedPackets
        diagnostic["mediaKeyPassedPackets"] = mediaKeys.passedPackets
        diagnostic["mediaKeyTapGeneration"] = mediaKeys.generation
        diagnostic["hudVisible"] = hud.isVisible
        diagnostic["hudPresentations"] = hud.presentations
        guard let path = argument("--status-file"), let data = try? JSONSerialization.data(withJSONObject: diagnostic, options: [.sortedKeys, .prettyPrinted]) else { return }
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    // Test commands exercise controller entry points without changing OS sleep state.
    func processTestCommand() {
        guard let path = argument("--command-file"), let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let command = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let token = command["token"] as? String, token != lastCommand else { return }
        lastCommand = token
        switch command["action"] as? String {
        case "sleep": audio.setSleeping(true)
        case "wake": audio.setSleeping(false)
        case "pause": audio.setPaused(true)
        case "resume": audio.setPaused(false)
        case "retry": retry()
        case "target": selectDevice(command["uid"] as? String ?? "")
        case "volume": if let n = command["value"] as? NSNumber { setVolume(n.doubleValue) }
        case "mute": audio.setMuted(true)
        case "unmute": audio.setMuted(false)
        case "media-key":
            if let raw = command["key"] as? Int, let key = VolumeKey(rawValue: raw) {
                let count = min(32, max(1, command["count"] as? Int ?? 1))
                for _ in 0..<count { handleVolumeKey(key, fine: command["fine"] as? Bool ?? false) }
            }
        default: break
        }
    }

    func setVolume(_ value: Double) {
        let snapshot = status()
        guard snapshot["state"] as? String == "active",
              snapshot["uid"] as? String == sliderState.deviceUID else { return }
        volumeChangeSequence &+= 1
        sliderState.userChanged(to: value)
        if !sliderState.isTracking { pendingSliderFeedbackUID = sliderState.deviceUID }
        audio.setVolumePercent(Float(sliderState.value)) { [weak self] _ in
            guard let self, !self.closing else { return }
            self.refresh()
        }
        refresh()
    }

    func toggleMute() {
        feedback?.cancel()
        pendingSliderFeedbackUID = nil
        audio.setMuted(!((status()["muted"] as? NSNumber)?.boolValue ?? false))
        refresh()
    }

    func handleVolumeKey(_ key: VolumeKey, fine: Bool) {
        guard !closing, audio.canHandleMediaKeys() else { return }
        let keyTime = ProcessInfo.processInfo.systemUptime
        volumeChangeSequence &+= 1
        pendingSliderFeedbackUID = nil
        if key == .mute { feedback?.cancel() }
        let sequence = volumeChangeSequence
        let uid = status()["uid"] as? String ?? ""
        audio.applyMediaKey(key.rawValue, fine: fine, deviceUID: uid) { [weak self] result in
            guard let self = self, !self.closing, let snapshot = result,
                  self.audio.canHandleMediaKeys(), self.status()["uid"] as? String == uid else { return }
            if sequence == self.volumeChangeSequence { self.sliderState.discardPending() }
            // Start the cue before the main-thread UI work so keys stay aligned
            // during repeats; the snapshot already contains the committed volume.
            if key != .mute { self.feedback?.request(forUID: uid, since: keyTime) }
            self.refresh()
            self.hud.show(percent: (snapshot["volume"] as? NSNumber)?.doubleValue ?? 50,
                muted: (snapshot["muted"] as? NSNumber)?.boolValue ?? false, deviceName: snapshot["name"] as? String ?? "")
            self.writeStatus(self.status())
        }
    }

    func enableMediaKeys() {
        AppLog.info("media.permissionMenuSelected")
        mediaKeys.requestPermission()
        if mediaKeys.state == "permission", let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        refresh()
    }

    func togglePause() {
        feedback?.cancel()
        audio.setPaused(!((status()["paused"] as? NSNumber)?.boolValue ?? false))
        refresh()
    }

    func retry() {
        audio.retry()
        refresh()
    }

    func selectDevice(_ uid: String) {
        feedback?.cancel()
        audio.setTargetDeviceUID(uid)
        refresh()
    }

    func setSelectedDeviceAsSystemOutput() {
        let uid = status()["targetUID"] as? String ?? ""
        guard !uid.isEmpty else { return }
        audio.setDefaultOutputDeviceUID(uid)
        refresh()
    }

    func openLogs() {
        AppLog.info("runtime.logsOpened", ["path": AppLog.logDirectoryURL.path])
        NSWorkspace.shared.open(AppLog.logDirectoryURL)
    }

    @objc func quitApp() {
        guard !closing else { return }
        AppLog.info("runtime.quitRequested")
        closing = true
        popover.performClose(nil)
        timer?.invalidate()
        mediaKeys.stop()
        feedback?.cancel()
        hud.hide()
        audio.stop {
            self.finished = true
            self.writeStatus(self.status())
            AppLog.info("runtime.stopped", ["reason": "menuOrSignal"])
            AppLog.flush()
            AppLog.stop()
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if finished { return .terminateNow }
        closing = true
        popover.performClose(nil)
        timer?.invalidate()
        mediaKeys.stop()
        feedback?.cancel()
        hud.hide()
        audio.stop {
            self.finished = true
            self.writeStatus(self.status())
            AppLog.info("runtime.stopped", ["reason": "systemTerminate"])
            AppLog.flush()
            AppLog.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
