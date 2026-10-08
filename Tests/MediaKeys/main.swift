import Foundation

func check(_ condition: @autoclosure () -> Bool, _ text: String) {
    guard condition() else { fatalError(text) }
}
func packet(_ key: Int, down: Bool = true, repeatKey: Bool = false) -> MediaKeyPacket {
    return MediaKeyPacket.decode(subtype: 8, data: key << 16 | (down ? 0x0a00 : 0x0b00) | (repeatKey ? 1 : 0))!
}
check(MediaKeyPacket.decode(subtype: 7, data: 0x0a00) == nil, "Other system events pass through")
check(MediaKeyPacket.decode(subtype: 8, data: 16 << 16 | 0x0a00) == nil, "Play/pause passes through")
check(MediaKeyPacket.decode(subtype: 8, data: 0x0100) == nil, "Unknown state passes through")
var router = MediaKeyRouter()
check(!router.route(packet(0), active: false).consume, "Native output down passes through")
check(!router.route(packet(0, down: false), active: false).consume, "Native output up passes through")
check(router.route(packet(0), active: true).action == .up, "Active volume up is handled")
for _ in 0..<12 { check(router.route(packet(0, repeatKey: true), active: true).action == .up, "Volume repeat is handled") }
check(router.route(packet(0, down: false), active: true).consume, "Captured up is suppressed")
check(router.route(packet(1), active: true).action == .down, "Down is handled")
check(router.route(packet(1, repeatKey: true), active: false).action == nil, "Switching output stops adjustment")
check(router.route(packet(1, down: false), active: false).consume, "Complete a captured key pair after switching output")
check(router.route(packet(7), active: true).action == .mute, "Mute toggles on first press")
check(router.route(packet(7, repeatKey: true), active: true).action == nil, "Mute repeat must not toggle")
check(router.route(packet(7), active: true).action == nil, "Duplicate mute down must not toggle")
check(router.route(packet(7, down: false), active: true).consume, "Mute release is suppressed")
check(router.route(packet(7), active: true).action == .mute, "Second physical press toggles again")
router.reset()
check(!router.route(packet(7, down: false), active: false).consume, "Teardown clears held keys")
print("PASS media keys: decode, repeats, mute debounce, native bypass, key pairing and teardown")
