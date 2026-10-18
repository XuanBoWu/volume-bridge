import AppKit

final class TrackingSlider: NSSlider {
    var trackingChanged: ((Bool) -> Void)?

    override func mouseDown(with event: NSEvent) {
        trackingChanged?(true)
        defer { trackingChanged?(false) }
        super.mouseDown(with: event)
    }
}

final class ControlPopoverViewController: NSViewController {
    var onVolumeChange: ((Double) -> Void)?
    var onTrackingChange: ((Bool) -> Void)?
    var onMute: (() -> Void)?
    var onPause: (() -> Void)?
    var onRetry: (() -> Void)?
    var onKeys: (() -> Void)?
    var onDeviceSelect: ((String) -> Void)?
    var onSetSystemOutput: (() -> Void)?
    var onLogs: (() -> Void)?
    var onQuit: (() -> Void)?

    private let panelWidth: CGFloat = 320
    private let devicePopup = NSPopUpButton()
    private let setSystemButton = NSButton()
    private let deviceNameLabel = NSTextField(labelWithString: "")
    private let deviceMetaLabel = NSTextField(labelWithString: "")
    private let stateIcon = NSImageView()
    private let stateLabel = NSTextField(labelWithString: "")
    private let outputDetailLabel = NSTextField(wrappingLabelWithString: "")
    private let originalVolumeLabel = NSTextField(wrappingLabelWithString: "")
    private let volumeValueLabel = NSTextField(labelWithString: "")
    private let slider = TrackingSlider(value: 50, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let muteButton = NSButton(title: "", target: nil, action: nil)
    private let keysStateLabel = NSTextField(labelWithString: "")
    private let keysButton = NSButton(title: "", target: nil, action: nil)
    private let pauseButton = NSButton(title: "", target: nil, action: nil)
    private let retryButton = NSButton(title: "", target: nil, action: nil)
    private let outputSectionLabel = NSTextField(labelWithString: "")
    private let volumeSectionLabel = NSTextField(labelWithString: "")
    private let keysSectionLabel = NSTextField(labelWithString: "")
    private let audioSectionLabel = NSTextField(labelWithString: "")
    private var deviceSignature = ""

    override func loadView() {
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.translatesAutoresizingMaskIntoConstraints = false

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .width
        root.distribution = .fill
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 14, right: 16)
        root.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            root.topAnchor.constraint(equalTo: effect.topAnchor),
            root.bottomAnchor.constraint(equalTo: effect.bottomAnchor)
        ])

        addFullWidth(makeHeader(), to: root)
        addFullWidth(makeSeparator(), to: root)
        addFullWidth(makeOutputSection(), to: root)
        addFullWidth(makeSeparator(), to: root)
        addFullWidth(makeVolumeSection(), to: root)
        addFullWidth(makeSeparator(), to: root)
        addFullWidth(makeKeysSection(), to: root)
        addFullWidth(makeAudioSection(), to: root)
        addFullWidth(makeFooter(), to: root)

        let controllerView = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: 430))
        controllerView.addSubview(effect)
        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: controllerView.leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: controllerView.trailingAnchor),
            effect.topAnchor.constraint(equalTo: controllerView.topAnchor),
            effect.bottomAnchor.constraint(equalTo: controllerView.bottomAnchor),
            controllerView.widthAnchor.constraint(equalToConstant: panelWidth)
        ])
        view = controllerView
        view.setAccessibilityRole(.group)
        view.setAccessibilityLabel(L10n.text("accessibility.controlPanel"))
    }

    private func makeHeader() -> NSView {
        let icon = NSImageView(image: NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: L10n.text("app.name")) ?? NSImage())
        icon.contentTintColor = .labelColor
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])

        let title = NSTextField(labelWithString: L10n.text("app.name"))
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        let subtitle = NSTextField(labelWithString: L10n.text("app.menuSubtitle"))
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        let text = NSStackView(views: [title, subtitle])
        text.orientation = .vertical
        text.distribution = .fill
        text.spacing = 1
        text.alignment = .leading

        let row = NSStackView(views: [icon, text])
        row.orientation = .horizontal
        row.distribution = .fill
        row.spacing = 8
        row.alignment = .centerY
        stretch(row)
        return row
    }

    private func makeOutputSection() -> NSView {
        styleSectionLabel(outputSectionLabel, key: "section.outputDevice")
        devicePopup.controlSize = .regular
        devicePopup.bezelStyle = .rounded
        devicePopup.target = self
        devicePopup.action = #selector(deviceSelected)
        devicePopup.setAccessibilityLabel(L10n.text("section.outputDevice"))
        devicePopup.setContentHuggingPriority(.defaultLow, for: .horizontal)

        setSystemButton.title = L10n.text("output.setSystem")
        setSystemButton.bezelStyle = .inline
        setSystemButton.isBordered = false
        setSystemButton.contentTintColor = .linkColor
        setSystemButton.target = self
        setSystemButton.action = #selector(setSystemOutput)
        setSystemButton.isHidden = true

        let deviceRow = NSStackView(views: [devicePopup, setSystemButton])
        deviceRow.orientation = .horizontal
        deviceRow.distribution = .fill
        deviceRow.spacing = 8
        deviceRow.alignment = .centerY
        stretch(deviceRow)

        deviceNameLabel.font = .systemFont(ofSize: 14)
        deviceMetaLabel.font = .systemFont(ofSize: 12)
        deviceMetaLabel.textColor = .secondaryLabelColor
        deviceMetaLabel.lineBreakMode = .byTruncatingTail
        let nameStack = NSStackView(views: [deviceNameLabel, deviceMetaLabel])
        nameStack.orientation = .vertical
        nameStack.distribution = .fill
        nameStack.spacing = 2
        nameStack.alignment = .leading

        stateIcon.imageScaling = .scaleProportionallyUpOrDown
        stateIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stateIcon.widthAnchor.constraint(equalToConstant: 13),
            stateIcon.heightAnchor.constraint(equalToConstant: 13)
        ])
        stateLabel.font = .systemFont(ofSize: 13)
        outputDetailLabel.font = .systemFont(ofSize: 12)
        outputDetailLabel.textColor = .secondaryLabelColor
        outputDetailLabel.maximumNumberOfLines = 2
        outputDetailLabel.alignment = .left
        let stateRow = NSStackView(views: [stateIcon, stateLabel])
        stateRow.orientation = .horizontal
        stateRow.distribution = .fill
        stateRow.spacing = 5
        stateRow.alignment = .centerY

        let content = NSStackView(views: [outputSectionLabel, deviceRow, nameStack, stateRow, outputDetailLabel])
        content.orientation = .vertical
        content.distribution = .fill
        content.spacing = 5
        content.alignment = .leading
        stretch(content)
        return content
    }

    private func makeVolumeSection() -> NSView {
        styleSectionLabel(volumeSectionLabel, key: "section.volume")
        volumeValueLabel.alignment = .right
        volumeValueLabel.font = .systemFont(ofSize: 14)
        volumeValueLabel.setContentHuggingPriority(.required, for: .horizontal)

        slider.isContinuous = true
        slider.setAccessibilityLabel(L10n.text("accessibility.volumeSlider"))
        slider.trackingChanged = { [weak self] tracking in self?.onTrackingChange?(tracking) }
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let titleRow = NSStackView(views: [volumeSectionLabel, NSView(), volumeValueLabel])
        titleRow.orientation = .horizontal
        titleRow.distribution = .fill
        titleRow.alignment = .centerY
        stretch(titleRow)

        let sliderRow = NSStackView(views: [slider])
        sliderRow.orientation = .horizontal
        sliderRow.distribution = .fill
        sliderRow.alignment = .centerY
        stretch(sliderRow)

        muteButton.bezelStyle = .rounded
        muteButton.controlSize = .regular
        muteButton.target = self
        muteButton.action = #selector(muteClicked)
        muteButton.setAccessibilityLabel(L10n.text("accessibility.mute"))
        let muteRow = NSStackView(views: [NSView(), muteButton])
        muteRow.orientation = .horizontal
        muteRow.distribution = .fill
        muteRow.alignment = .centerY
        stretch(muteRow)

        let content = NSStackView(views: [titleRow, sliderRow, muteRow])
        content.orientation = .vertical
        content.distribution = .fill
        content.spacing = 7
        content.alignment = .leading
        stretch(content)
        return content
    }

    private func makeKeysSection() -> NSView {
        styleSectionLabel(keysSectionLabel, key: "section.keyboard")
        keysStateLabel.font = .systemFont(ofSize: 13)
        keysStateLabel.textColor = .secondaryLabelColor
        keysButton.bezelStyle = .rounded
        keysButton.controlSize = .small
        keysButton.target = self
        keysButton.action = #selector(keysClicked)
        let row = NSStackView(views: [keysStateLabel, NSView(), keysButton])
        row.orientation = .horizontal
        row.distribution = .fill
        row.alignment = .centerY
        row.spacing = 8
        stretch(row)
        let content = NSStackView(views: [keysSectionLabel, row])
        content.orientation = .vertical
        content.distribution = .fill
        content.spacing = 5
        content.alignment = .leading
        stretch(content)
        return content
    }

    private func makeAudioSection() -> NSView {
        styleSectionLabel(audioSectionLabel, key: "section.audioLink")
        let actionRow = NSStackView(views: [pauseButton, retryButton])
        actionRow.orientation = .horizontal
        actionRow.distribution = .fillEqually
        actionRow.spacing = 8
        pauseButton.bezelStyle = .rounded
        pauseButton.controlSize = .regular
        pauseButton.target = self
        pauseButton.action = #selector(pauseClicked)
        retryButton.bezelStyle = .rounded
        retryButton.controlSize = .regular
        retryButton.target = self
        retryButton.action = #selector(retryClicked)
        originalVolumeLabel.font = .systemFont(ofSize: 12)
        originalVolumeLabel.textColor = .secondaryLabelColor
        originalVolumeLabel.maximumNumberOfLines = 2
        originalVolumeLabel.setAccessibilityLabel(L10n.text("accessibility.audioDetail"))
        stretch(actionRow)
        let content = NSStackView(views: [audioSectionLabel, originalVolumeLabel, actionRow])
        content.orientation = .vertical
        content.distribution = .fill
        content.spacing = 5
        content.alignment = .leading
        stretch(content)
        return content
    }

    private func makeFooter() -> NSView {
        let logs = NSButton(title: L10n.text("menu.openLogs"), target: self, action: #selector(logsClicked))
        logs.bezelStyle = .inline
        logs.isBordered = false
        logs.alignment = .left
        logs.contentTintColor = .linkColor
        let quit = NSButton(title: L10n.text("menu.quit"), target: self, action: #selector(quitClicked))
        quit.bezelStyle = .inline
        quit.isBordered = false
        quit.alignment = .right
        quit.contentTintColor = .linkColor
        let content = NSStackView(views: [logs, quit])
        content.orientation = .horizontal
        content.distribution = .fillEqually
        stretch(content)
        return content
    }

    private func makeSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    private func addFullWidth(_ view: NSView, to stack: NSStackView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        stretch(view)
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalToConstant: panelWidth - 32).isActive = true
    }

    private func styleSectionLabel(_ label: NSTextField, key: String) {
        label.stringValue = L10n.text(key)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .left
    }

    private func stretch(_ view: NSView) {
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    func update(snapshot: [String: Any], mediaState: String, sliderValue: Double, sliderEnabled: Bool, muted: Bool, devices: [[String: Any]]) {
        updateDeviceMenu(devices, targetUID: snapshot["targetUID"] as? String ?? "")
        let state = snapshot["state"] as? String ?? "stopped"
        let name = snapshot["name"] as? String ?? ""
        let detail = snapshot["detail"] as? String ?? ""
        let sampleRate = (snapshot["rate"] as? NSNumber)?.doubleValue ?? 0
        let channels = (snapshot["channels"] as? NSNumber)?.intValue ?? 0
        let stateText = L10n.stateLabel(state)
        deviceNameLabel.stringValue = name.isEmpty ? L10n.text("menu.noOutput") : name
        deviceMetaLabel.stringValue = sampleRate > 0 ? L10n.format("output.format", Int(sampleRate.rounded()), channels) : L10n.text("output.waiting")
        stateLabel.stringValue = stateText
        outputDetailLabel.stringValue = detail
        stateIcon.image = NSImage(systemSymbolName: symbol(for: state, muted: muted), accessibilityDescription: stateText)
        stateIcon.contentTintColor = color(for: state)
        let targetUID = snapshot["targetUID"] as? String ?? ""
        let targetMatches = (snapshot["targetMatchesSystem"] as? NSNumber)?.boolValue ?? true
        setSystemButton.isHidden = targetUID.isEmpty || targetMatches
        volumeValueLabel.stringValue = L10n.percent(sliderValue)
        if !slider.isHighlighted { slider.doubleValue = sliderValue }
        slider.isEnabled = sliderEnabled
        muteButton.title = muted ? L10n.text("menu.unmute") : L10n.text("menu.mute")
        muteButton.state = muted ? .on : .off
        muteButton.isEnabled = sliderEnabled
        let keysReady = mediaState == "ready"
        keysStateLabel.stringValue = L10n.text(keysReady ? "keys.ready" : mediaState == "permission" ? "keys.permission" : "keys.unavailable")
        keysStateLabel.textColor = keysReady ? .systemGreen : .secondaryLabelColor
        keysButton.title = L10n.text("menu.enableKeys")
        keysButton.isEnabled = !keysReady
        keysButton.isHidden = keysReady
        let paused = (snapshot["paused"] as? NSNumber)?.boolValue == true
        pauseButton.title = paused ? L10n.text("menu.resume") : L10n.text("menu.pause")
        pauseButton.isEnabled = state == "active" || paused
        retryButton.title = L10n.text("menu.rebuild")
        retryButton.isEnabled = state != "starting" && state != "recovering"
        originalVolumeLabel.stringValue = L10n.text("menu.originalVolume")
    }

    private func updateDeviceMenu(_ devices: [[String: Any]], targetUID: String) {
        let signature = devices.map { "\($0["uid"] as? String ?? ""): \($0["name"] as? String ?? ""): \(($0["current"] as? NSNumber)?.boolValue ?? false)" }.joined(separator: "|")
        if signature != deviceSignature {
            deviceSignature = signature
            devicePopup.removeAllItems()
            devicePopup.addItem(withTitle: L10n.text("output.followSystem"))
            devicePopup.lastItem?.representedObject = ""
            for device in devices {
                let item = devicePopup.menu?.addItem(withTitle: device["name"] as? String ?? "", action: nil, keyEquivalent: "")
                item?.representedObject = device["uid"] as? String ?? ""
            }
        }
        if targetUID.isEmpty {
            devicePopup.selectItem(at: 0)
        } else if let index = devicePopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == targetUID }) {
            devicePopup.selectItem(at: index)
        }
    }

    private func symbol(for state: String, muted: Bool) -> String {
        if state == "active" { return muted ? "speaker.slash.fill" : "speaker.wave.2.fill" }
        switch state {
        case "paused": return "pause.circle"
        case "sleeping": return "moon.zzz"
        case "error": return "exclamationmark.triangle"
        case "waiting", "starting", "recovering": return "ellipsis.circle"
        default: return "speaker.wave.2"
        }
    }

    private func color(for state: String) -> NSColor {
        switch state {
        case "active": return .systemGreen
        case "error": return .systemRed
        case "starting", "recovering": return .systemBlue
        default: return .secondaryLabelColor
        }
    }

    @objc private func deviceSelected() {
        onDeviceSelect?(devicePopup.selectedItem?.representedObject as? String ?? "")
    }

    @objc private func setSystemOutput() { onSetSystemOutput?() }
    @objc private func sliderChanged() { onVolumeChange?(slider.doubleValue) }
    @objc private func muteClicked() { onMute?() }
    @objc private func pauseClicked() { onPause?() }
    @objc private func retryClicked() { onRetry?() }
    @objc private func keysClicked() { onKeys?() }
    @objc private func logsClicked() { onLogs?() }
    @objc private func quitClicked() { onQuit?() }
}

