import AppKit

private final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class VolumeBar: NSView {
    var percent: Double = 0 { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3).fill()
        if percent > 0 {
            NSColor.white.withAlphaComponent(0.9).setFill()
            let filled = NSRect(x: 0, y: 0, width: bounds.width * min(100, percent) / 100, height: bounds.height)
            NSBezierPath(roundedRect: filled, xRadius: 3, yRadius: 3).fill()
        }
    }
}

final class VolumeHUD {
    private let panel = HUDPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 116),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let icon = NSImageView(frame: NSRect(x: 22, y: 57, width: 32, height: 32))
    private let label = NSTextField(labelWithString: L10n.percent(50))
    private let device = NSTextField(labelWithString: "")
    private let bar = VolumeBar(frame: NSRect(x: 22, y: 22, width: 216, height: 6))
    private var hideTimer: Timer?
    private(set) var presentations = 0
    var isVisible: Bool { panel.isVisible }

    init() {
        panel.title = L10n.text("hud.title")
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 260, height: 116))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.appearance = NSAppearance(named: .vibrantDark)
        background.wantsLayer = true
        background.layer?.cornerRadius = 18
        background.layer?.masksToBounds = true
        icon.contentTintColor = .white
        label.frame = NSRect(x: 70, y: 62, width: 168, height: 30)
        label.font = .monospacedDigitSystemFont(ofSize: 25, weight: .semibold)
        label.textColor = .white
        device.frame = NSRect(x: 70, y: 43, width: 168, height: 16)
        device.font = .systemFont(ofSize: 11)
        device.textColor = NSColor.white.withAlphaComponent(0.7)
        device.lineBreakMode = .byTruncatingTail
        for view in [icon, label, device, bar] as [NSView] { background.addSubview(view) }
        panel.contentView = background
    }

    func show(percent: Double, muted: Bool, deviceName: String) {
        hideTimer?.invalidate()
        presentations += 1
        let silent = muted || percent <= 0
        let symbol = silent ? "speaker.slash.fill" : percent < 35 ? "speaker.wave.1.fill" : "speaker.wave.2.fill"
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: L10n.text(silent ? "accessibility.muted" : "accessibility.volume"))
        label.stringValue = muted ? L10n.text("hud.muted") : L10n.percent(percent)
        device.stringValue = deviceName
        bar.percent = silent ? 0 : percent
        panel.setAccessibilityLabel(L10n.format("hud.accessibility", L10n.text("app.name"), deviceName, label.stringValue))
        let screen = NSScreen.screens.first { $0.localizedName.caseInsensitiveCompare(deviceName) == .orderedSame }
            ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let screen = screen {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.minY + 72))
        }
        panel.orderFrontRegardless()
        let timer = Timer(timeInterval: 1.4, repeats: false) { [weak self] _ in self?.hide() }
        hideTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        panel.orderOut(nil)
    }
}
