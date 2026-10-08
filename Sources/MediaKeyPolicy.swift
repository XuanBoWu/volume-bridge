import Foundation

// NX_KEYTYPE_SOUND_UP / SOUND_DOWN / MUTE from IOKit ev_keymap.h.
enum VolumeKey: Int { case up = 0, down = 1, mute = 7 }

struct MediaKeyPacket {
    let key: VolumeKey
    let isDown: Bool
    let isRepeat: Bool
    static func decode(subtype: Int, data: Int) -> MediaKeyPacket? {
        guard subtype == 8 else { return nil } // NX_SUBTYPE_AUX_CONTROL_BUTTONS
        let bits = UInt32(truncatingIfNeeded: data)
        guard let key = VolumeKey(rawValue: Int(bits >> 16)) else { return nil }
        let state = (bits >> 8) & 0xff
        guard state == 0x0a || state == 0x0b else { return nil }
        return MediaKeyPacket(key: key, isDown: state == 0x0a, isRepeat: bits & 1 != 0)
    }
}

struct MediaKeyRouter {
    private var held = Set<Int>()
    mutating func reset() { held.removeAll() }
    mutating func route(_ packet: MediaKeyPacket, active: Bool) -> (consume: Bool, action: VolumeKey?) {
        if !packet.isDown {
            return (held.remove(packet.key.rawValue) != nil, nil)
        }
        if !active { return (held.contains(packet.key.rawValue), nil) }
        let wasHeld = !held.insert(packet.key.rawValue).inserted
        // A held mute key must toggle only once, including duplicate down events.
        if packet.key == .mute && (packet.isRepeat || wasHeld) { return (true, nil) }
        return (true, packet.key)
    }
}
