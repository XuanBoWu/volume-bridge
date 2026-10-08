import AppKit
import Foundation

final class TrackingSlider: NSSlider {
    var trackingChanged: ((Bool) -> Void)?
    override func mouseDown(with event: NSEvent) {
        trackingChanged?(true)
        defer { trackingChanged?(false) }
        super.mouseDown(with: event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let audio = DVAudioController()
    var item: NSStatusItem!
    let menu = NSMenu()
    let deviceItem = NSMenuItem(title: L10n.text("menu.readingDevice"), action: nil, keyEquivalent: "")
    let stateItem = NSMenuItem(title: L10n.text("menu.preparing"), action: nil, keyEquivalent: "")
    let detailLabel = NSTextField(wrappingLabelWithString: "")
    let volumeLabel = NSTextField(labelWithString: L10n.format("volume.label", L10n.percent(50)))
    let slider = TrackingSlider(value: 50, minValue: 0, maxValue: 100, target: nil, action: nil)
    var sliderState = VolumeSliderState()
    var volumeChangeSequence: UInt64 = 0
    let mediaKeys = MediaKeys()
    let hud = VolumeHUD()
    let keysItem = NSMenuItem(title: L10n.text("menu.enableKeys"), action: #selector(enableMediaKeys), keyEquivalent: "")
    let muteItem = NSMenuItem(title: L10n.text("menu.mute"), action: #selector(toggleMute), keyEquivalent: "")
    let pauseItem = NSMenuItem(title: L10n.text("menu.pause"), action: #selector(togglePause), keyEquivalent: "")
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
        if let path = argument("--log") {
            freopen(path, "a", stderr)
            setbuf(stderr, nil)
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: L10n.text("app.name"))
        item.menu = menu
        menu.delegate = self
        menu.autoenablesItems = false
        menu.addItem(NSMenuItem(title: L10n.text("app.menuTitle"), action: nil, keyEquivalent: ""))
        menu.addItem(deviceItem)
        menu.addItem(stateItem)
        let detail = NSMenuItem()
        detailLabel.frame = NSRect(x: 12, y: 6, width: 256, height: 44)
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        let detailView = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 56))
        detailView.addSubview(detailLabel)
        detail.view = detailView
        menu.addItem(detail)
        menu.addItem(.separator())
        let volume = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 60))
        volumeLabel.frame = NSRect(x: 14, y: 35, width: 250, height: 18)
        slider.frame = NSRect(x: 12, y: 8, width: 254, height: 24)
        slider.target = self
        slider.action = #selector(volumeChanged)
        slider.isContinuous = true
        slider.setAccessibilityLabel(L10n.text("accessibility.volumeSlider"))
        slider.trackingChanged = { [weak self] tracking in
            guard let self = self else { return }
            if tracking {
                self.sliderState.beginTracking()
            } else {
                self.sliderState.endTracking()
                self.refresh()
            }
        }
        view.addSubview(volumeLabel)
        view.addSubview(slider)
        volume.view = view
        menu.addItem(volume)
        muteItem.target = self
        pauseItem.target = self
        menu.addItem(muteItem)
        menu.addItem(pauseItem)
        keysItem.target = self
        menu.addItem(keysItem)
        let retry = NSMenuItem(title: L10n.text("menu.rebuild"), action: #selector(retry), keyEquivalent: "")
        retry.target = self
        menu.addItem(retry)
        menu.addItem(.separator())
        let originalVolume = NSMenuItem()
        let originalView = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 46))
        let originalLabel = NSTextField(wrappingLabelWithString: L10n.text("menu.originalVolume"))
        originalLabel.frame = NSRect(x: 12, y: 6, width: 256, height: 34)
        originalLabel.font = .systemFont(ofSize: 11)
        originalLabel.textColor = .secondaryLabelColor
        originalView.addSubview(originalLabel)
        originalVolume.view = originalView
        menu.addItem(originalVolume)
        let quit = NSMenuItem(title: L10n.text("menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
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
        audio.start()
        mediaKeys.shouldHandle = { [weak self] in self?.closing == false && self?.audio.canHandleMediaKeys() == true }
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
    }
    func status() -> [String: Any] { audio.snapshot() }
    func refresh() {
        let s = status()
        let state = s["state"] as? String ?? "stopped"
        let name = s["name"] as? String ?? ""
        let stateLabel = L10n.stateLabel(state)
        deviceItem.title = name.isEmpty ? L10n.text("menu.noOutput") : name
        stateItem.title = stateLabel
        detailLabel.stringValue = s["detail"] as? String ?? ""
        let percent = (s["volume"] as? NSNumber)?.doubleValue ?? 50
        let muted = (s["muted"] as? NSNumber)?.boolValue ?? false
        sliderState.refresh(volume: percent, uid: s["uid"] as? String ?? "", enabled: state == "active")
        updateVolumeLabel(muted: muted && sliderState.pendingValue == nil)
        // Even assigning the old value during AppKit tracking can reset the thumb.
        if !sliderState.isTracking {
            if slider.doubleValue != sliderState.value { slider.doubleValue = sliderState.value }
            if slider.isEnabled != (state == "active") { slider.isEnabled = state == "active" }
        }
        muteItem.isEnabled = state == "active"
        muteItem.state = muted ? .on : .off
        pauseItem.state = (s["paused"] as? NSNumber)?.boolValue == true ? .on : .off
        keysItem.title = L10n.text(mediaKeys.state == "ready" ? "keys.ready" : mediaKeys.state == "permission" ? "keys.permission" : "keys.unavailable")
        keysItem.isEnabled = mediaKeys.state != "ready"
        if state != "active" { hud.hide() }
        item.button?.image = NSImage(systemSymbolName: muted && state == "active" ? "speaker.slash" : "speaker.wave.2", accessibilityDescription: L10n.text("app.name"))
        item.button?.toolTip = L10n.format("app.tooltip", L10n.text("app.name"), stateLabel, name)
        writeStatus(s)
    }
    func writeStatus(_ s: [String: Any]) {
        var diagnostic = s
        diagnostic["mediaKeysState"] = mediaKeys.state
        diagnostic["mediaKeyPresses"] = mediaKeys.acceptedPresses
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
        case "retry": audio.retry()
        case "volume": if let n = command["value"] as? NSNumber { audio.setVolumePercent(n.floatValue) }
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
    func menuWillOpen(_ menu: NSMenu) { refresh() }
    func updateVolumeLabel(muted: Bool) {
        volumeLabel.stringValue = L10n.format(muted ? "volume.labelMuted" : "volume.label", L10n.percent(sliderState.value))
    }
    @objc func volumeChanged() {
        let s = status()
        guard s["state"] as? String == "active", s["uid"] as? String == sliderState.deviceUID else { return }
        volumeChangeSequence &+= 1
        sliderState.userChanged(to: slider.doubleValue)
        updateVolumeLabel(muted: false)
        audio.setVolumePercent(Float(sliderState.value))
    }
    @objc func toggleMute() { audio.setMuted(!((status()["muted"] as? NSNumber)?.boolValue ?? false)) }
    func handleVolumeKey(_ key: VolumeKey, fine: Bool) {
        guard !closing, audio.canHandleMediaKeys() else { return }
        volumeChangeSequence &+= 1
        let sequence = volumeChangeSequence
        let uid = status()["uid"] as? String ?? ""
        audio.applyMediaKey(key.rawValue, fine: fine, deviceUID: uid) { [weak self] result in
            guard let self = self, !self.closing, let s = result,
                  self.audio.canHandleMediaKeys(), self.status()["uid"] as? String == uid else { return }
            if sequence == self.volumeChangeSequence { self.sliderState.discardPending() }
            self.refresh()
            self.hud.show(percent: (s["volume"] as? NSNumber)?.doubleValue ?? 50,
                muted: (s["muted"] as? NSNumber)?.boolValue ?? false, deviceName: s["name"] as? String ?? "")
            self.writeStatus(self.status())
        }
    }
    @objc func enableMediaKeys() {
        mediaKeys.requestPermission()
        if mediaKeys.state == "permission", let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        refresh()
    }
    @objc func togglePause() { audio.setPaused(!((status()["paused"] as? NSNumber)?.boolValue ?? false)) }
    @objc func retry() { audio.retry() }
    @objc func quitApp() {
        guard !closing else { return }
        closing = true
        timer?.invalidate()
        mediaKeys.stop()
        hud.hide()
        audio.stop {
            self.finished = true
            self.writeStatus(self.status())
            NSApp.terminate(nil)
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if finished { return .terminateNow }
        closing = true
        timer?.invalidate()
        mediaKeys.stop()
        hud.hide()
        audio.stop {
            self.finished = true
            self.writeStatus(self.status())
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
