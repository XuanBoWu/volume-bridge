import AppKit

let logDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("VolumeBridge-feedback-\(UUID())")
AppLog.start(overridePath: logDirectory.appendingPathComponent("test.log").path)
defer {
    AppLog.stop()
    try? FileManager.default.removeItem(at: logDirectory)
}

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

func snapshot(_ percent: Double = 50, muted: Bool = false, state: String = "active", uid: String = "monitor", eligible: Bool = true) -> [String: Any] {
    ["uid": uid, "volume": percent, "muted": muted, "state": state, "canHandleMediaKeys": eligible]
}

check(VolumeFeedbackContext(snapshot: snapshot()).gain == 0.25, "50% uses the same square curve exactly once")
check(VolumeFeedbackContext(snapshot: snapshot(100)).gain == 1, "Full volume endpoint")
for value in [0.0, -1.0, Double.nan, Double.infinity] {
    check(VolumeFeedbackContext(snapshot: snapshot(value)).gain == nil, "Invalid or silent level must not sound")
}
check(VolumeFeedbackContext(snapshot: snapshot(muted: true)).gain == nil, "Muted means silent")
check(VolumeFeedbackContext(snapshot: snapshot(uid: "")).gain == nil, "No output means silent")
check(VolumeFeedbackContext(snapshot: snapshot(eligible: false)).gain == nil, "Mismatched system output means silent")
for state in ["paused", "bypass", "waiting", "sleeping", "recovering", "error"] {
    check(VolumeFeedbackContext(snapshot: snapshot(state: state)).gain == nil, "Inactive output must not sound")
}

var limit = VolumeFeedbackRateLimit()
check(limit.delay(at: 10) == 0, "The first cue is immediate")
limit.didPlay(at: 10)
check(abs(limit.delay(at: 10.01) - 0.01) < 0.0001, "Same-burst duplicates are collapsed")
check(limit.delay(at: 10.05) == 0, "Human key repeats are not paced by the dedupe window")
check(limit.delay(at: 11) == 0, "The dedupe window expires")

let fallback = VolumeFeedbackTone.fallbackWAV()
check(String(data: fallback.prefix(4), encoding: .ascii) == "RIFF", "Valid fallback container")
check(String(data: fallback[8..<12], encoding: .ascii) == "WAVE", "Fallback is a WAV")
let decoded = NSSound(data: fallback)
check(decoded != nil && decoded!.duration > 0 && decoded!.duration < 0.15, "Fallback decodes to a short sound without playback")
check(fallback[44] == 0 && fallback[45] == 0 && fallback.suffix(2).allSatisfy { $0 == 0 }, "Fallback fades to zero at both endpoints")

final class StateBox {
    private let lock = NSLock()
    private var value = snapshot()
    func read() -> [String: Any] { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ value: [String: Any]) { lock.lock(); self.value = value; lock.unlock() }
}

final class FakeSound: VolumeFeedbackPlaying {
    private let lock = NSLock()
    private var values: [(String, Float)] = []
    let played = DispatchSemaphore(value: 0)
    func play(uid: String, gain: Float) -> Bool {
        lock.lock(); values.append((uid, gain)); lock.unlock()
        played.signal()
        return true
    }
    func stop() {}
    var gains: [Float] { lock.lock(); defer { lock.unlock() }; return values.map { $0.1 } }
}

let state = StateBox()
let player = FakeSound()
let feedback = VolumeFeedback(snapshot: { state.read() }, player: player)
feedback.request(forUID: "monitor")
check(player.played.wait(timeout: .now() + 1) == .success, "First feedback is immediate")
for _ in 0..<40 { feedback.request(forUID: "monitor") }
state.set(snapshot(25))
feedback.request(forUID: "monitor")
check(player.played.wait(timeout: .now() + 1) == .success, "Burst has a final cue")
check(player.gains.count == 2 && player.gains.last == 0.0625, "Burst coalesces and uses the latest volume")

feedback.request(forUID: "monitor")
state.set(snapshot(muted: true))
feedback.synchronize()
check(player.played.wait(timeout: .now() + 0.2) == .timedOut, "Mute cancels pending feedback")

state.set(snapshot(uid: "other"))
feedback.request(forUID: "monitor")
check(player.played.wait(timeout: .now() + 0.2) == .timedOut, "A stale device request is discarded")
state.set(snapshot(state: "bypass"))
feedback.request(forUID: "monitor")
check(player.played.wait(timeout: .now() + 0.2) == .timedOut, "Native bypass leaves system feedback alone")
feedback.cancel()
print("PASS volume feedback: square gain, silent states, latest-value coalescing, mute/device cancellation and fallback decoding; no sound played")
