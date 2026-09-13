import XCTest
#if canImport(LockInCore)
@testable import LockInCore
#else
@testable import LockIn
#endif

final class TimekeeperModelsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testCountdownUsesDeadlineAndPauseSnapshot() {
        let start = date(2026, 9, 13, 8)
        var countdown = CountdownState(
            durationSeconds: 300,
            pausedRemainingSeconds: 300,
            deadline: start.addingTimeInterval(300)
        )
        XCTAssertEqual(countdown.remaining(at: start.addingTimeInterval(91)), 209)
        countdown.pausedRemainingSeconds = countdown.remaining(at: start.addingTimeInterval(91))
        countdown.deadline = nil
        XCTAssertEqual(countdown.remaining(at: start.addingTimeInterval(999)), 209)
    }

    func testStopwatchKeepsAccurateElapsedTimeAcrossNavigation() {
        let start = date(2026, 9, 13, 8)
        let running = StopwatchState(elapsedBeforeRun: 12.5, startedAt: start)
        XCTAssertEqual(running.elapsed(at: start.addingTimeInterval(20)), 32.5, accuracy: 0.0001)
        let paused = StopwatchState(elapsedBeforeRun: running.elapsed(at: start.addingTimeInterval(20)))
        XCTAssertEqual(paused.elapsed(at: start.addingTimeInterval(500)), 32.5, accuracy: 0.0001)
    }

    func testRepeatingAlarmFindsNextChosenWeekday() {
        let monday = date(2026, 9, 14, 9)
        let alarm = Alarm(timeMinutes: 8 * 60 + 30, repeatWeekdays: [2, 4])
        XCTAssertEqual(alarm.nextFireDate(after: monday, calendar: calendar), date(2026, 9, 16, 8, 30))
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 9, 16, 8), calendar: calendar), date(2026, 9, 16, 8, 30))
    }

    func testOneTimeAlarmExpiresAndDisabledAlarmNeverFires() {
        let now = date(2026, 9, 13, 8)
        let future = Alarm(timeMinutes: 9 * 60, oneTimeDate: date(2026, 9, 13, 9))
        XCTAssertEqual(future.nextFireDate(after: now, calendar: calendar), date(2026, 9, 13, 9))
        XCTAssertNil(future.nextFireDate(after: date(2026, 9, 13, 10), calendar: calendar))
        var disabled = future
        disabled.enabled = false
        XCTAssertNil(disabled.nextFireDate(after: now, calendar: calendar))
    }

    func testTimekeeperStateRoundTripsAndFormattingIsStable() throws {
        let state = TimekeeperState(
            countdown: CountdownState(durationSeconds: 1500, pausedRemainingSeconds: 812),
            stopwatch: StopwatchState(elapsedBeforeRun: 65.43),
            alarms: [Alarm(timeMinutes: 7 * 60, repeatWeekdays: [2, 3, 4, 5, 6])]
        )
        let restored = try JSONDecoder().decode(TimekeeperState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored, state)
        XCTAssertEqual(TimeFormat.clock(65), "01:05")
        XCTAssertEqual(TimeFormat.clock(3661), "01:01:01")
        XCTAssertEqual(TimeFormat.stopwatch(65.43), "01:05.43")
    }

    func testTimekeeperStorePersistsAtomically() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TimekeeperStore(url: directory.appendingPathComponent("timekeeper.json"))
        let state = TimekeeperState(alarms: [Alarm(timeMinutes: 420, repeatWeekdays: [1, 7])])
        try store.save(state)
        XCTAssertEqual(try store.load(), state)
    }
}
