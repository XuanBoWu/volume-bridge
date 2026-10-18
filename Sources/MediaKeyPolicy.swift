import Foundation

// NX_KEYTYPE_SOUND_UP / SOUND_DOWN / MUTE from IOKit ev_keymap.h.
enum VolumeKey: Int { case up = 0, down = 1, mute = 7 }

// An enabled Mach port can survive an output transition without receiving
// media keys. Rebind it when a new audio session becomes eligible, including
// same-UID rebuilds that happen between UI refreshes.
struct MediaKeyAudioSession: Equatable {
    let uid: String
    let deviceID: UInt32
    let generation: UInt64

    init?(snapshot: [String: Any]) {
        guard snapshot["state"] as? String == "active",
              (snapshot["canHandleMediaKeys"] as? NSNumber)?.boolValue == true,
              let uid = snapshot["uid"] as? String, !uid.isEmpty,
              let id = snapshot["deviceID"] as? NSNumber, id.uint32Value != 0,
              let generation = snapshot["generation"] as? NSNumber else { return nil }
        self.uid = uid
        deviceID = id.uint32Value
        self.generation = generation.uint64Value
    }
}

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
