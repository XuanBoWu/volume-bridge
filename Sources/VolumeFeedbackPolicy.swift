import Foundation

struct VolumeFeedbackContext {
    let uid: String
    let percent: Double
    let muted: Bool
    let active: Bool

    init(snapshot: [String: Any]) {
        uid = snapshot["uid"] as? String ?? ""
        percent = (snapshot["volume"] as? NSNumber)?.doubleValue ?? .nan
        muted = (snapshot["muted"] as? NSNumber)?.boolValue ?? true
        active = snapshot["state"] as? String == "active"
            && (snapshot["canHandleMediaKeys"] as? NSNumber)?.boolValue == true
    }

    // Our process is excluded from the tap. Apply the DSP curve once to our cue.
    var gain: Float? {
        guard active, !uid.isEmpty, !muted, percent.isFinite, percent > 0 else { return nil }
        let fraction = min(100, percent) / 100
        return Float(fraction * fraction)
    }
}

struct VolumeFeedbackRateLimit {
    // Human key repeat is slower than this. The window only collapses duplicate
    // events delivered in the same burst; it must not pace normal key presses.
    static let interval: TimeInterval = 0.02
    private var lastPlayedAt: TimeInterval?

    func delay(at now: TimeInterval) -> TimeInterval {
        guard let lastPlayedAt else { return 0 }
        return max(0, Self.interval - (now - lastPlayedAt))
    }

    mutating func didPlay(at now: TimeInterval) { lastPlayedAt = now }
}

enum VolumeFeedbackTone {
    // An original short, faded tone if the system volume-feedback asset moves.
    // Generate only synthetic PCM in memory; never save or copy user audio.
    static func fallbackWAV() -> Data {
        let rate = 44_100
        let count = rate / 12
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + count * 2))
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(rate)); append(UInt32(rate * 2))
        append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: "data".utf8); append(UInt32(count * 2))
        for index in 0..<count {
            let t = Double(index) / Double(rate)
            let fadeIn = min(1, Double(index) / 220)
            let fadeOut = min(1, Double(count - 1 - index) / 440)
            let wave = sin(2 * Double.pi * 600 * t) + 0.2 * sin(2 * Double.pi * 1200 * t)
            append(Int16(wave * fadeIn * fadeOut * exp(-45 * t) * 10_000))
        }
        return data
    }
}
