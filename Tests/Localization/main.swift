import Foundation

func argument(_ name: String) -> String {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { fatalError("Missing \(name)") }
    return args[i + 1]
}
func check(_ value: @autoclosure () -> Bool, _ text: String) {
    guard value() else { fatalError(text) }
}
let language = argument("--expect-language")
let chinese = language == "zh-Hans"
check(Bundle.main.preferredLocalizations.first == language, "System language selection / fallback failed")
check(L10n.text("app.name") == (chinese ? "音桥" : "VolumeBridge"), "App name translation")
check(L10n.text("menu.mute") == (chinese ? "静音" : "Mute"), "Menu translation")
check(L10n.text("hud.muted") == (chinese ? "静音" : "Muted"), "HUD translation")
check(L10n.percent(50) == argument("--expect-percent"), "Percent must use the current region")
check(L10n.format("volume.label", L10n.percent(50)).contains(L10n.percent(50)), "Volume label formatting")
check(L10n.format("app.tooltip", "App", "State", "Device") == "App · State · Device", "Positional placeholders")
for state in ["active", "bypass", "starting", "recovering", "sleeping", "paused", "waiting", "error", "unsupported", "stopped"] {
    check(!L10n.stateLabel(state).hasPrefix("state."), "Missing state translation")
}
check(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == (chinese ? "音桥" : "VolumeBridge"), "Localized metadata app name")
let capture = Bundle.main.object(forInfoDictionaryKey: "NSAudioCaptureUsageDescription") as? String ?? ""
check(capture.contains(chinese ? "不保存、不上传" : "never saved or uploaded"), "Localized capture permission explanation")
// Constructing the controller reads its initial status; do not start audio or request permissions.
let audio = DVAudioController()
check(audio.snapshot()["detail"] as? String == (chinese ? "尚未启动" : "Not started"), "Objective-C++ status translation")
print("PASS runtime localization: \(language), percent=\(L10n.percent(50)), metadata and controller; no audio started")
