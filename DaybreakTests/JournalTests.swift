import Foundation
import Testing
@testable import Daybreak

struct DayKeyTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func formatsAsIsoDay() {
        #expect(DayKey(date(9, 22, 8, 0), calendar: calendar).rawValue == "2026-09-22")
        #expect(DayKey(date(1, 5, 23, 59), calendar: calendar).rawValue == "2026-01-05")
    }

    @Test func midnightStartsANewDay() {
        #expect(DayKey(date(9, 22, 23, 59), calendar: calendar) != DayKey(date(9, 23, 0, 0), calendar: calendar))
    }

    @Test func encodesAsAPlainString() throws {
        let data = try JSONEncoder().encode(DayKey(rawValue: "2026-09-22"))
        #expect(String(decoding: data, as: UTF8.self) == "\"2026-09-22\"")
        #expect(try JSONDecoder().decode(DayKey.self, from: data) == DayKey(rawValue: "2026-09-22"))
    }
}

struct JournalStreakTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 9))!
    }

    func keys(_ dates: [Date]) -> Set<DayKey> {
        Set(dates.map { DayKey($0, calendar: calendar) })
    }

    @Test func countsBackFromToday() {
        let days = keys([day(9, 22), day(9, 21), day(9, 20), day(9, 17)])
        #expect(JournalStreak.count(days: days, today: day(9, 22), calendar: calendar) == 3)
    }

    @Test func todayNotYetDoneStillCountsYesterday() {
        let days = keys([day(9, 21), day(9, 20)])
        #expect(JournalStreak.count(days: days, today: day(9, 22), calendar: calendar) == 2)
    }

    @Test func aGapBreaksTheStreak() {
        let days = keys([day(9, 20), day(9, 19)])
        #expect(JournalStreak.count(days: days, today: day(9, 22), calendar: calendar) == 0)
    }

    @Test func emptyJournalIsZero() {
        #expect(JournalStreak.count(days: [], today: day(9, 22), calendar: calendar) == 0)
    }
}
