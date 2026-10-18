import AppKit
import ApplicationServices

protocol MediaKeyListening: AnyObject {
    var isValid: Bool { get }
    var isEnabled: Bool { get }
    func enable()
    func start()
    func stop()
}

struct MediaKeyCallbacks {
    let shouldHandle: () -> Bool
    let onAction: (VolumeKey, Bool) -> Void
    let onDisabled: (UInt32) -> Void
    let onPacket: (MediaKeyPacket, Bool, Bool) -> Void
}

// The event tap has its own run loop: AppKit rendering and audio-service IPC
// must never delay the system's synchronous event delivery.
private final class MediaKeyEventTap: MediaKeyListening {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var router = MediaKeyRouter()
    private let lifecycleLock = NSLock()
    private var runLoop: CFRunLoop?
    private var stopping = false
    private let shouldHandle: () -> Bool
    private let onAction: (VolumeKey, Bool) -> Void
    private let onDisabled: (UInt32) -> Void
    private let onPacket: (MediaKeyPacket, Bool, Bool) -> Void

    init?(callbacks: MediaKeyCallbacks) {
        shouldHandle = callbacks.shouldHandle
        onAction = callbacks.onAction
        onDisabled = callbacks.onDisabled
        onPacket = callbacks.onPacket
        let context = Unmanaged.passUnretained(self).toOpaque()
        // System-defined media events only; ordinary keys are never requested.
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask(1) << 14,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<MediaKeyEventTap>.fromOpaque(context).takeUnretainedValue().receive(type: type, event: event)
            }, userInfo: context) else { return nil }
        CGEvent.tapEnable(tap: newTap, enable: false)
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            return nil
        }
        tap = newTap
        source = newSource
    }

    var isValid: Bool { tap.map { CFMachPortIsValid($0) } ?? false }
    var isEnabled: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }
    func enable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    func start() {
        let thread = Thread { [self] in
            let loop = CFRunLoopGetCurrent()!
            lifecycleLock.lock()
            runLoop = loop
            let cancelled = stopping
            lifecycleLock.unlock()
            if !cancelled, let source {
                CFRunLoopAddSource(loop, source, .commonModes)
                enable()
                CFRunLoopRun()
                CFRunLoopRemoveSource(loop, source, .commonModes)
            }
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: false)
                CFMachPortInvalidate(tap)
            }
            lifecycleLock.lock()
            runLoop = nil
            lifecycleLock.unlock()
        }
        thread.name = "VolumeBridge.MediaKeys"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    func stop() {
        lifecycleLock.lock()
        stopping = true
        let loop = runLoop
        lifecycleLock.unlock()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let loop {
            CFRunLoopPerformBlock(loop, CFRunLoopMode.defaultMode.rawValue) { CFRunLoopStop(loop) }
            CFRunLoopWakeUp(loop)
        }
    }

    private func receive(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        autoreleasepool { route(type: type, event: event) }
    }

    private func route(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        lifecycleLock.lock()
        let cancelled = stopping
        lifecycleLock.unlock()
        if cancelled { return Unmanaged.passUnretained(event) }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            router.reset()
            enable()
            onDisabled(type.rawValue)
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == 14, let ns = NSEvent(cgEvent: event),
              ns.type == .systemDefined,
              let packet = MediaKeyPacket.decode(subtype: Int(ns.subtype.rawValue), data: ns.data1) else {
            return Unmanaged.passUnretained(event)
        }
        let active = shouldHandle()
        let result = router.route(packet, active: active)
        onPacket(packet, active, result.consume)
        if let key = result.action {
            onAction(key, ns.modifierFlags.contains([.shift, .option]))
        }
        return result.consume ? nil : Unmanaged.passUnretained(event)
    }
}

final class MediaKeys {
    // This closure runs on the tap thread and must only read thread-safe cached state.
    var shouldHandle: (() -> Bool)?
    var onKey: ((VolumeKey, Bool) -> Void)?
    private var worker: MediaKeyListening?
    private(set) var generation: UInt64 = 0
    private var audioSession: MediaKeyAudioSession?
    private let isTrusted: () -> Bool
    private let makeWorker: (MediaKeyCallbacks) -> MediaKeyListening?
    private var nextAttempt: TimeInterval = 0
    private(set) var acceptedPresses = 0
    private(set) var receivedPackets = 0
    private(set) var passedPackets = 0
    private(set) var state = "permission"

    init(isTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
         makeWorker: ((MediaKeyCallbacks) -> MediaKeyListening?)? = nil) {
        self.isTrusted = isTrusted
        self.makeWorker = makeWorker ?? { MediaKeyEventTap(callbacks: $0) }
    }

    func synchronizeAudio(_ snapshot: [String: Any]) {
        let session = MediaKeyAudioSession(snapshot: snapshot)
        let changed = session != audioSession
        audioSession = session
        guard changed, let session else { return }
        // Keep listening while bypassed so macOS receives native volume keys,
        // but never reuse that listener when software control resumes.
        if worker != nil {
            AppLog.info("media.audioSessionRebind", ["uid": session.uid,
                "audioGeneration": session.generation, "deviceID": session.deviceID])
            stop()
            nextAttempt = 0
        }
        refreshPermission()
    }

    private func setState(_ newState: String, reason: String) {
        guard state != newState else { return }
        let oldState = state
        state = newState
        AppLog.info("media.permissionState", ["from": oldState, "to": newState, "reason": reason])
    }

    func requestPermission() {
        AppLog.info("media.permissionRequested")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        nextAttempt = 0
        refreshPermission()
    }

    func refreshPermission() {
        guard isTrusted() else {
            if worker != nil { stop() }
            setState("permission", reason: "accessibilityNotTrusted")
            return
        }
        if let worker, worker.isValid {
            if !worker.isEnabled { worker.enable() }
            setState(worker.isEnabled ? "ready" : "unavailable", reason: "existingTap")
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard now >= nextAttempt else { return }
        stop()
        nextAttempt = now + 2
        let token = generation
        let handler = shouldHandle ?? { false }
        let callbacks = MediaKeyCallbacks(shouldHandle: handler,
            onAction: { [weak self] key, fine in
                // Preserve ordering without waiting for the main run loop.
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == token else { return }
                    self.acceptedPresses += 1
                    AppLog.debug("media.keyReceived", ["key": key.rawValue, "fine": fine, "consumed": true])
                    self.onKey?(key, fine)
                }
            },
            onDisabled: { [weak self] type in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == token else { return }
                    AppLog.warning("media.eventTapDisabled", ["type": type])
                }
            },
            onPacket: { [weak self] packet, active, consumed in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == token else { return }
                    self.receivedPackets += 1
                    if !consumed { self.passedPackets += 1 }
                    AppLog.debug("media.volumePacket", ["key": packet.key.rawValue,
                        "down": packet.isDown, "repeat": packet.isRepeat,
                        "active": active, "consumed": consumed])
                }
            })
        guard let newWorker = makeWorker(callbacks) else {
            AppLog.warning("media.eventTapCreateFailed")
            setState("unavailable", reason: "eventTapCreateFailed")
            return
        }
        worker = newWorker
        newWorker.start()
        AppLog.info("media.eventTapReady", ["thread": "VolumeBridge.MediaKeys", "generation": generation])
        setState("ready", reason: "eventTapCreated")
    }

    func stop() {
        generation &+= 1
        worker?.stop()
        worker = nil
        setState("stopped", reason: "stopped")
    }
}
