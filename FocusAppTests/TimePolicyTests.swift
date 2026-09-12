import XCTest
#if canImport(LockInCore)
@testable import LockInCore
#else
@testable import LockIn
#endif

final class TimePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    func testEveryPresetExpiresAtDeadlineIncludingThirtySeconds() {
        for seconds in TimePolicy.unlockDurations {
            let start = date(2026, 9, 5)
            let deadline = UnlockDeadline(seconds: seconds, now: start, uptime: 1000)
            XCTAssertTrue(deadline.isActive(now: start.addingTimeInterval(Double(seconds) - 1), uptime: 1000 + Double(seconds) - 1))
            XCTAssertFalse(deadline.isActive(now: start.addingTimeInterval(Double(seconds)), uptime: 1000 + Double(seconds)))
        }
    }
    func testClockChangesAndRebootCannotExtendAccess() {
        let start = date(2026, 9, 5)
        let deadline = UnlockDeadline(seconds: 300, now: start, uptime: 1000)
        XCTAssertFalse(deadline.isActive(now: start.addingTimeInterval(-60), uptime: 1100))
        XCTAssertFalse(deadline.isActive(now: start.addingTimeInterval(60), uptime: 1310))
        XCTAssertFalse(deadline.isActive(now: start.addingTimeInterval(60), uptime: 10))
        XCTAssertFalse(deadline.isActive(now: start.addingTimeInterval(600), uptime: 1060))
        XCTAssertFalse(deadline.isActive(now: start.addingTimeInterval(200), uptime: 1060))
    }
    func testDeadlineRoundTripsAcrossProcessRestart() throws {
        let start = date(2026, 9, 5)
        let deadline = UnlockDeadline(seconds: 60, now: start, uptime: 1000)
        let restored = try JSONDecoder().decode(UnlockDeadline.self, from: JSONEncoder().encode(deadline))
        XCTAssertTrue(restored.isActive(now: start.addingTimeInterval(30), uptime: 1030))
        XCTAssertFalse(restored.isActive(now: start.addingTimeInterval(60), uptime: 1060))
    }
    func testCustomDurationBounds() {
        XCTAssertFalse(TimePolicy.validDuration(0))
        XCTAssertFalse(TimePolicy.validDuration(29))
        XCTAssertTrue(TimePolicy.validDuration(30))
        XCTAssertTrue(TimePolicy.validDuration(86400))
        XCTAssertFalse(TimePolicy.validDuration(86401))
    }
    func testYearProgressResetsAndHandlesLeapYear() {
        XCTAssertEqual(TimePolicy.yearProgress(at: date(2026, 1, 1), calendar: calendar), 0)
        XCTAssertEqual(TimePolicy.yearProgress(at: date(2027, 1, 1), calendar: calendar), 0)
        XCTAssertEqual(TimePolicy.yearProgress(at: date(2024, 7, 2), calendar: calendar), 0.5, accuracy: 0.000001)
        XCTAssertGreaterThan(TimePolicy.yearProgress(at: date(2026, 12, 31, 23), calendar: calendar), 0.999)
    }
    func testFixed2026To2027ProgressClampsOutsideInterval() {
        XCTAssertEqual(TimePolicy.yearProgress(from: 2026, at: date(2025, 12, 31), calendar: calendar), 0)
        XCTAssertEqual(TimePolicy.yearProgress(from: 2026, at: date(2026, 1, 1), calendar: calendar), 0)
        XCTAssertEqual(TimePolicy.yearProgress(from: 2026, at: date(2027, 1, 1), calendar: calendar), 1)
        XCTAssertEqual(TimePolicy.yearProgress(from: 2026, at: date(2028, 1, 1), calendar: calendar), 1)
    }
    func testMonthAndHabitPeriodsHaveCorrectBoundaries() {
        XCTAssertEqual(TimePolicy.monthDays(containing: date(2024, 2, 20), calendar: calendar).count, 29)
        XCTAssertEqual(TimePolicy.monthDays(containing: date(2026, 2, 20), calendar: calendar).count, 28)
        XCTAssertEqual(HabitPeriod.day.days(containing: date(2026, 9, 5), calendar: calendar).count, 1)
        XCTAssertEqual(HabitPeriod.week.days(containing: date(2026, 9, 5), calendar: calendar).first, date(2026, 8, 31))
        XCTAssertEqual(HabitPeriod.year.days(containing: date(2024, 9, 5), calendar: calendar).count, 366)
        XCTAssertEqual(HabitPeriod.year.days(containing: date(2026, 9, 5), calendar: calendar).count, 365)
    }
    func testDSTDoesNotDropOrDuplicateHabitDays() {
        var local = calendar
        local.timeZone = TimeZone(identifier: "America/New_York")!
        let spring = HabitPeriod.month.days(containing: date(2026, 3, 15), calendar: local)
        let autumn = HabitPeriod.month.days(containing: date(2026, 11, 15), calendar: local)
        XCTAssertEqual(spring.count, 31)
        XCTAssertEqual(autumn.count, 30)
        XCTAssertEqual(Set(spring.map { TimePolicy.dayKey($0, calendar: local) }).count, 31)
        XCTAssertEqual(Set(autumn.map { TimePolicy.dayKey($0, calendar: local) }).count, 30)
    }
}
