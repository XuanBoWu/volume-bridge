import AppKit
import ApplicationServices

final class MediaKeys {
    var shouldHandle: (() -> Bool)?
    var onKey: ((VolumeKey, Bool) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var router = MediaKeyRouter()
    private var nextAttempt: TimeInterval = 0
    private(set) var acceptedPresses = 0
    private(set) var state = "permission"

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        nextAttempt = 0
        refreshPermission()
    }

    func refreshPermission() {
        guard AXIsProcessTrusted() else {
            if tap != nil { stop() }
            state = "permission"
            return
        }
        if let tap = tap, CFMachPortIsValid(tap) {
            if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            state = CGEvent.tapIsEnabled(tap: tap) ? "ready" : "unavailable"
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard now >= nextAttempt else { return }
        stop()
        nextAttempt = now + 2
        let context = Unmanaged.passUnretained(self).toOpaque()
        // System-defined events only. Ordinary keyboard and mouse events are not requested.
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask(1) << 14,
            callback: { _, type, event, context in
                guard let context = context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<MediaKeys>.fromOpaque(context).takeUnretainedValue().receive(type: type, event: event)
            }, userInfo: context),
            let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            state = "unavailable"
            return
        }
        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        state = "ready"
    }

    private func receive(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            router.reset()
            if let tap = tap, AXIsProcessTrusted() { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == 14, let ns = NSEvent(cgEvent: event),
              ns.type == .systemDefined,
              let packet = MediaKeyPacket.decode(subtype: Int(ns.subtype.rawValue), data: ns.data1) else {
            return Unmanaged.passUnretained(event)
        }
        let result = router.route(packet, active: shouldHandle?() == true)
        if let key = result.action {
            acceptedPresses += 1
            let fine = ns.modifierFlags.contains([.shift, .option])
            onKey?(key, fine)
        }
        return result.consume ? nil : Unmanaged.passUnretained(event)
    }

    func stop() {
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap = tap { CFMachPortInvalidate(tap) }
        tap = nil
        source = nil
        router.reset()
        state = "stopped"
    }
}
