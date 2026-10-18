import AppKit

protocol VolumeFeedbackPlaying {
    func play(uid: String, gain: Float) -> Bool
    func stop()
}

private final class SystemVolumeFeedbackSound: VolumeFeedbackPlaying {
    private var sound: NSSound?
    private var deviceUID: String?

    init() {
        // Load once at launch so the first key press does not pay for file IO.
        let path = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
        sound = NSSound(contentsOfFile: path, byReference: false)
        if sound == nil { sound = NSSound(data: VolumeFeedbackTone.fallbackWAV()) }
        if sound == nil { AppLog.warning("feedback.soundUnavailable") }
    }

    func play(uid: String, gain: Float) -> Bool {
        guard let sound else { return false }
        // An explicit UID avoids the separate system-alert output destination.
        // Restarting on every press keeps the cue aligned with the key; the
        // native volume feedback also cuts the previous tail.
        sound.stop()
        if deviceUID != uid {
            sound.playbackDeviceIdentifier = uid
            deviceUID = uid
        }
        sound.volume = gain
        sound.currentTime = 0
        return sound.play()
    }

    func stop() { sound?.stop() }
}

final class VolumeFeedback {
    private let queue = DispatchQueue(label: "local.displayvolume.feedback", qos: .userInteractive)
    private let snapshot: () -> [String: Any]
    private let player: VolumeFeedbackPlaying
    private var pending: DispatchWorkItem?
    private var activeUID: String?
    private var rateLimit = VolumeFeedbackRateLimit()

    init(snapshot: @escaping () -> [String: Any], player: VolumeFeedbackPlaying? = nil) {
        self.snapshot = snapshot
        self.player = player ?? SystemVolumeFeedbackSound()
    }

    func request(forUID uid: String, since: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        queue.async { [self] in
            pending?.cancel()
            let context = VolumeFeedbackContext(snapshot: snapshot())
            guard context.uid == uid, context.gain != nil else { clear(); return }
            if activeUID != uid { player.stop() }
            activeUID = uid
            let work = DispatchWorkItem { [weak self] in self?.playLatest(forUID: uid, since: since) }
            pending = work
            let delay = rateLimit.delay(at: ProcessInfo.processInfo.systemUptime)
            if delay <= 0 {
                queue.async(execute: work)
            } else {
                queue.asyncAfter(deadline: .now() + delay, execute: work)
            }
        }
    }

    func synchronize() {
        queue.async { [self] in
            let context = VolumeFeedbackContext(snapshot: snapshot())
            if context.gain == nil || (activeUID != nil && activeUID != context.uid) { clear() }
        }
    }

    func cancel() { queue.async { [self] in clear() } }

    private func clear() {
        pending?.cancel()
        pending = nil
        player.stop()
        activeUID = nil
    }

    private func playLatest(forUID uid: String, since: TimeInterval) {
        let context = VolumeFeedbackContext(snapshot: snapshot())
        guard context.uid == uid, let gain = context.gain else { clear(); return }
        let now = ProcessInfo.processInfo.systemUptime
        if player.play(uid: uid, gain: gain) {
            rateLimit.didPlay(at: now)
            AppLog.debug("feedback.played", [
                "uid": uid,
                "percent": context.percent,
                "gain": gain,
                "latencyMs": Int(max(0, now - since) * 1000 + 0.5),
            ])
        } else {
            AppLog.warning("feedback.playFailed", ["uid": uid])
        }
        pending = nil
    }
}
