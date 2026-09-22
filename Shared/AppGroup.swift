import Foundation
import os

/// The app group shared by the app and its three extensions.
/// The identifier must match `com.apple.security.application-groups` in every target's entitlements (see project.yml).
nonisolated enum AppGroup {
    static let identifier = "group.com.pranavgadiraju.daybreak"

    /// The shared defaults suite. Falls back to standard defaults (and logs a fault) if the entitlement is missing,
    /// so a misconfigured build fails loudly in Console rather than silently.
    static var defaults: UserDefaults {
        if let suite = UserDefaults(suiteName: identifier) {
            return suite
        }
        Log.app.fault("App group \(identifier, privacy: .public) is unavailable; check the App Groups entitlement")
        return .standard
    }

    /// The shared container directory, where the journal file lives.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

nonisolated enum Log {
    static let subsystem = "com.pranavgadiraju.daybreak"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let monitor = Logger(subsystem: subsystem, category: "monitor")
    static let shield = Logger(subsystem: subsystem, category: "shield")
}
