import Foundation

enum AppLog {
    static var logDirectoryURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Logs/VolumeBridge", isDirectory: true)
    }

    static func start(overridePath: String?) {
        DVLogger.start(withOverridePath: overridePath)
    }

    static func debug(_ event: String, _ fields: [String: Any] = [:]) {
        DVLogger.log(with: .debug, event: event, fields: fields)
    }

    static func info(_ event: String, _ fields: [String: Any] = [:]) {
        DVLogger.log(with: .info, event: event, fields: fields)
    }

    static func notice(_ event: String, _ fields: [String: Any] = [:]) {
        DVLogger.log(with: .notice, event: event, fields: fields)
    }

    static func warning(_ event: String, _ fields: [String: Any] = [:]) {
        DVLogger.log(with: .warning, event: event, fields: fields)
    }

    static func error(_ event: String, _ fields: [String: Any] = [:]) {
        DVLogger.log(with: .error, event: event, fields: fields)
    }

    static func critical(_ event: String, _ fields: [String: Any] = [:]) {
        DVLogger.log(with: .critical, event: event, fields: fields)
    }

    static func flush() { DVLogger.flush() }
    static func stop() { DVLogger.stop() }
}
