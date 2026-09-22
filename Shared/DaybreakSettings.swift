import FamilyControls
import Foundation

/// A wall-clock time of day in the device's local time zone.
nonisolated struct TimeOfDay: Hashable, Codable, Sendable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    static let defaultStart = TimeOfDay(hour: 7, minute: 0)

    /// DeviceActivity needs at least 15 minutes between a schedule's start and its 23:59 end.
    static let latestAllowedStart = TimeOfDay(hour: 23, minute: 44)

    var minutesSinceMidnight: Int { hour * 60 + minute }
    var components: DateComponents { DateComponents(hour: hour, minute: minute) }
    var isAllowedStart: Bool { minutesSinceMidnight <= Self.latestAllowedStart.minutesSinceMidnight }

    /// This time on the same calendar day as `day`.
    func date(on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }
}

nonisolated extension TimeOfDay: Comparable {
    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

/// How high the bar is. The thresholds live in `RubricThresholds`.
nonisolated enum Strictness: String, CaseIterable, Codable, Sendable, Identifiable {
    case relaxed
    case standard
    case strict

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relaxed: "Relaxed"
        case .standard: "Standard"
        case .strict: "Strict"
        }
    }

    var summary: String {
        switch self {
        case .relaxed:
            "2+ goals of 3+ words and a 25-word reflection. No check for action verbs."
        case .standard:
            "3+ goals of 4+ words that start with an action, and a 40-word reflection."
        case .strict:
            "3+ goals of 5+ words that start with an action, one with a number or a time, an 80-word reflection, and goals that differ from yesterday's."
        }
    }
}

/// Typed access to the values the app and its extensions share through the app group.
/// Reads and writes go straight to `UserDefaults`, which is thread-safe, so this is usable from any isolation.
nonisolated struct SharedState {
    let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    private enum Key {
        static let selection = "selection"
        static let startHour = "startHour"
        static let startMinute = "startMinute"
        static let scheduleEnabled = "scheduleEnabled"
        static let clearedDay = "clearedDay"
        static let strictness = "strictness"
        static let draft = "draft"
        static let onboardingComplete = "onboardingComplete"
        static let all = [selection, startHour, startMinute, scheduleEnabled, clearedDay, strictness, draft, onboardingComplete]
    }

    /// Wipe everything. Used by the UI tests (launch argument `--reset-state`).
    func resetAll() {
        for key in Key.all {
            defaults.removeObject(forKey: key)
        }
    }

    /// The picked apps, categories and web domains, as opaque system tokens.
    var selection: FamilyActivitySelection? {
        get {
            guard let data = defaults.data(forKey: Key.selection) else { return nil }
            return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        }
        nonmutating set {
            defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.selection)
        }
    }

    var startTime: TimeOfDay {
        get {
            guard defaults.object(forKey: Key.startHour) != nil else { return .defaultStart }
            return TimeOfDay(hour: defaults.integer(forKey: Key.startHour), minute: defaults.integer(forKey: Key.startMinute))
        }
        nonmutating set {
            defaults.set(newValue.hour, forKey: Key.startHour)
            defaults.set(newValue.minute, forKey: Key.startMinute)
        }
    }

    var isScheduleEnabled: Bool {
        get { defaults.bool(forKey: Key.scheduleEnabled) }
        nonmutating set { defaults.set(newValue, forKey: Key.scheduleEnabled) }
    }

    /// The local day whose reflection was approved. Equal to today means unlocked.
    var clearedDay: DayKey? {
        get { defaults.string(forKey: Key.clearedDay).map(DayKey.init(rawValue:)) }
        nonmutating set { defaults.set(newValue?.rawValue, forKey: Key.clearedDay) }
    }

    var strictness: Strictness {
        get { defaults.string(forKey: Key.strictness).flatMap(Strictness.init(rawValue:)) ?? .standard }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.strictness) }
    }

    var draftData: Data? {
        get { defaults.data(forKey: Key.draft) }
        nonmutating set { defaults.set(newValue, forKey: Key.draft) }
    }

    var isOnboardingComplete: Bool {
        get { defaults.bool(forKey: Key.onboardingComplete) }
        nonmutating set { defaults.set(newValue, forKey: Key.onboardingComplete) }
    }
}
