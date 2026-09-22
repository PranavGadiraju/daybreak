import Foundation
import Testing
@testable import Daybreak

struct ShieldPolicyTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    func policy(clearedDay: DayKey? = nil, enabled: Bool = true) -> ShieldPolicy {
        ShieldPolicy(startTime: TimeOfDay(hour: 7, minute: 0), isScheduleEnabled: enabled, clearedDay: clearedDay, calendar: calendar)
    }

    @Test func beforeTheStartTimeNothingIsShielded() {
        #expect(policy().phase(at: date(9, 22, 6, 30)) == .beforeStart(startsAt: date(9, 22, 7, 0)))
    }

    @Test func fromTheStartTimeTheShieldIsOn() {
        #expect(policy().phase(at: date(9, 22, 7, 0)) == .shielded(since: date(9, 22, 7, 0)))
        #expect(policy().phase(at: date(9, 22, 22, 45)) == .shielded(since: date(9, 22, 7, 0)))
        #expect(policy().shouldShield(at: date(9, 22, 12, 0)))
    }

    @Test func clearedTodayStaysClearedUntilTomorrowsStart() {
        let today = DayKey(date(9, 22, 8, 0), calendar: calendar)
        #expect(policy(clearedDay: today).phase(at: date(9, 22, 9, 0)) == .cleared(resumesAt: date(9, 23, 7, 0)))
        #expect(policy(clearedDay: today).phase(at: date(9, 22, 23, 30)) == .cleared(resumesAt: date(9, 23, 7, 0)))
    }

    @Test func yesterdaysClearanceDoesNotCarryOver() {
        let yesterday = DayKey(date(9, 21, 8, 0), calendar: calendar)
        #expect(policy(clearedDay: yesterday).phase(at: date(9, 22, 8, 0)) == .shielded(since: date(9, 22, 7, 0)))
        #expect(policy(clearedDay: yesterday).phase(at: date(9, 22, 6, 0)) == .beforeStart(startsAt: date(9, 22, 7, 0)))
    }

    @Test func scheduleOffMeansOff() {
        #expect(policy(enabled: false).phase(at: date(9, 22, 9, 0)) == .off)
        #expect(!policy(enabled: false).shouldShield(at: date(9, 22, 9, 0)))
    }

    @Test func monthEndRollsOverCorrectly() {
        let lastOfMonth = DayKey(date(9, 30, 8, 0), calendar: calendar)
        #expect(policy(clearedDay: lastOfMonth).phase(at: date(9, 30, 20, 0)) == .cleared(resumesAt: date(10, 1, 7, 0)))
        #expect(policy(clearedDay: lastOfMonth).phase(at: date(10, 1, 8, 0)) == .shielded(since: date(10, 1, 7, 0)))
    }
}

struct TimeOfDayTests {
    @Test func startMustLeaveRoomForTheInterval() {
        #expect(TimeOfDay(hour: 7, minute: 0).isAllowedStart)
        #expect(TimeOfDay(hour: 23, minute: 44).isAllowedStart)
        #expect(!TimeOfDay(hour: 23, minute: 45).isAllowedStart)
        #expect(!TimeOfDay(hour: 23, minute: 59).isAllowedStart)
    }

    @Test func roundTripsThroughADate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 12, minute: 30))!
        let time = TimeOfDay(noon, calendar: calendar)
        #expect(time == TimeOfDay(hour: 12, minute: 30))
        #expect(time.date(on: noon, calendar: calendar) == noon)
    }
}
