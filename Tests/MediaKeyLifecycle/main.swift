import Foundation

let logDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("VolumeBridge-media-lifecycle-\(UUID())")
AppLog.start(overridePath: logDirectory.appendingPathComponent("test.log").path)
defer {
    AppLog.stop()
    try? FileManager.default.removeItem(at: logDirectory)
}

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

final class Listener: MediaKeyListening {
    var isValid = true
    var isEnabled = false
    var starts = 0
    var stops = 0
    let callbacks: MediaKeyCallbacks
    init(_ callbacks: MediaKeyCallbacks) { self.callbacks = callbacks }
    func enable() { isEnabled = true }
    func start() { starts += 1; isEnabled = true }
    func stop() { stops += 1; isValid = false; isEnabled = false }
}

func snapshot(_ uid: String = "display", id: UInt32 = 131, generation: UInt64 = 1,
              state: String = "active", eligible: Bool = true) -> [String: Any] {
    ["uid": uid, "deviceID": id, "generation": generation,
     "state": state, "canHandleMediaKeys": eligible]
}

var trusted = true
var listeners: [Listener] = []
let keys = MediaKeys(isTrusted: { trusted }, makeWorker: { callbacks in
    let listener = Listener(callbacks)
    listeners.append(listener)
    return listener
})
keys.shouldHandle = { true }
var actions = 0
keys.onKey = { _, _ in actions += 1 }
keys.refreshPermission()
check(listeners.count == 1 && keys.state == "ready", "Initial permission creates listener")
keys.synchronizeAudio(snapshot())
check(listeners.count == 2 && listeners[0].stops == 1, "First audio session binds a fresh listener")
for _ in 0..<20 {
    keys.synchronizeAudio(snapshot())
    keys.refreshPermission()
}
check(listeners.count == 2, "Stable audio must not recreate the tap on every refresh/key")
// Model the reported failure: old tap still claims valid/enabled across bypass.
keys.synchronizeAudio(snapshot(state: "bypass", eligible: false))
check(listeners.count == 2 && listeners[1].isEnabled, "Native bypass retains pass-through listener")
keys.synchronizeAudio(snapshot())
check(listeners.count == 3 && listeners[1].stops == 1, "Returning to same device replaces a seemingly healthy tap")
keys.synchronizeAudio(snapshot(generation: 2))
check(listeners.count == 4 && listeners[2].stops == 1, "Fast same-UID rebuild observed only via generation rebinds")
keys.synchronizeAudio(snapshot("other", id: 456, generation: 2))
check(listeners.count == 5, "Different active UID/device ID rebinds")
keys.synchronizeAudio(snapshot("other", id: 789, generation: 2))
check(listeners.count == 6, "Reassigned device ID rebinds")
keys.synchronizeAudio(snapshot("other", id: 789, generation: 2, state: "waiting", eligible: false))
keys.synchronizeAudio(snapshot("other", id: 789, generation: 3))
check(listeners.count == 7 && listeners.dropLast().allSatisfy { $0.stops == 1 }, "Every replaced listener stops once")
let packet = MediaKeyPacket(key: .down, isDown: true, isRepeat: false)
listeners[1].callbacks.onAction(.down, false)
listeners[1].callbacks.onPacket(packet, true, true)
listeners.last!.callbacks.onPacket(packet, true, true)
listeners.last!.callbacks.onAction(.down, false)
RunLoop.main.run(until: Date().addingTimeInterval(0.03))
check(actions == 1 && keys.acceptedPresses == 1 && keys.receivedPackets == 1,
      "Queued callbacks from obsolete generations are discarded")
trusted = false
keys.refreshPermission()
check(keys.state == "permission" && listeners.last!.stops == 1, "Revoked trust stops the new listener")
print("PASS media-key lifecycle: rebind on output return/session rebuild, retain native pass-through, reject stale callbacks; no system tap or keys created")
