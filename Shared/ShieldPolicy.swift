import Foundation

/// What the Today screen shows and what the shield should be doing right now.
nonisolated enum ShieldPhase: Equatable, Sendable {
    /// The schedule is turned off.
    case off
    /// Earlier than today's start time and today is not cleared.
    case beforeStart(startsAt: Date)
    /// At or past the start time and today is not cleared: the shield is on.
    case shielded(since: Date)
    /// Today's reflection was approved: the shield stays off until tomorrow's start.
    case cleared(resumesAt: Date)

    var isShielded: Bool {
        if case .shielded = self { return true }
        return false
    }
}

/// The one rule the app and the monitor extension both follow. Pure and testable.
nonisolated struct ShieldPolicy: Sendable {
    var startTime: TimeOfDay
    var isScheduleEnabled: Bool
    var clearedDay: DayKey?
    var calendar: Calendar = .current

    func phase(at now: Date) -> ShieldPhase {
        guard isScheduleEnabled, let todayStart = startTime.date(on: now, calendar: calendar) else {
            return .off
        }
        if clearedDay == DayKey(now, calendar: calendar) {
            let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
            return .cleared(resumesAt: tomorrowStart)
        }
        if now < todayStart {
            return .beforeStart(startsAt: todayStart)
        }
        return .shielded(since: todayStart)
    }

    func shouldShield(at now: Date) -> Bool {
        phase(at: now).isShielded
    }
}
