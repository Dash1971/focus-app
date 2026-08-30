import XCTest
@testable import LockIn

final class ScheduleTimingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testDaytimeScheduleUsesSelectedWeekdayAndEndIsExclusive() {
        let monday = date(2026, 8, 31, 10, 0)
        let end = date(2026, 8, 31, 11, 0)

        XCTAssertTrue(ScheduleTiming.isActive(startMinutes: 10 * 60, endMinutes: 11 * 60, weekdays: [2], at: monday, calendar: calendar))
        XCTAssertFalse(ScheduleTiming.isActive(startMinutes: 10 * 60, endMinutes: 11 * 60, weekdays: [2], at: end, calendar: calendar))
    }

    func testOvernightScheduleCarriesItsStartingWeekdayPastMidnight() {
        let fridayNight = date(2026, 9, 4, 23, 0)
        let saturdayMorning = date(2026, 9, 5, 1, 0)
        let saturdayNight = date(2026, 9, 5, 23, 0)

        XCTAssertTrue(ScheduleTiming.isActive(startMinutes: 22 * 60, endMinutes: 7 * 60, weekdays: [6], at: fridayNight, calendar: calendar))
        XCTAssertTrue(ScheduleTiming.isActive(startMinutes: 22 * 60, endMinutes: 7 * 60, weekdays: [6], at: saturdayMorning, calendar: calendar))
        XCTAssertFalse(ScheduleTiming.isActive(startMinutes: 22 * 60, endMinutes: 7 * 60, weekdays: [6], at: saturdayNight, calendar: calendar))
    }

    func testEqualTimesAreNotTreatedAsAlwaysActive() {
        XCTAssertFalse(ScheduleTiming.isActive(startMinutes: 600, endMinutes: 600, weekdays: Set(1...7), at: date(2026, 8, 31, 10, 0), calendar: calendar))
    }

    func testOvernightEndDateFallsOnFollowingDayBeforeMidnight() {
        let fridayNight = date(2026, 9, 4, 23, 0)
        let expected = date(2026, 9, 5, 7, 0)

        XCTAssertEqual(ScheduleTiming.activeEndDate(startMinutes: 22 * 60, endMinutes: 7 * 60, at: fridayNight, calendar: calendar), expected)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
