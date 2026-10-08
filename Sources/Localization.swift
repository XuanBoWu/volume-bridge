import Foundation

enum L10n {
    static func text(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }
    static func percent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: min(100, max(0, value)) / 100)) ?? "\(Int(value.rounded()))%"
    }
    static func stateLabel(_ state: String) -> String {
        let keys = ["active": "state.active", "bypass": "state.bypass", "starting": "state.starting",
            "recovering": "state.recovering", "sleeping": "state.sleeping", "paused": "state.paused",
            "waiting": "state.waiting", "error": "state.error", "unsupported": "state.unsupported", "stopped": "state.stopped"]
        return keys[state].map(text) ?? state
    }
}
