import XCTest
#if canImport(LockInCore)
@testable import LockInCore
#else
@testable import LockIn
#endif

final class LifeStoreTests: XCTestCase {
    func testEventsHabitsNotesAndPreferencesSurviveReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("life.json")
        var state = LifeState()
        state.events = [CalendarEvent(title: "My Birthday", day: "2026-09-05", color: .blue, important: true)]
        state.habits = [Habit(name: "Read", completedDays: ["2026-09-04", "2026-09-05"])]
        state.notes = [Note(title: "Thoughts", body: "First line\n日本語 🔒")]
        state.habitPeriod = .year
        state.showHabitHistory = false
        try LifeStore(url: url).save(state)
        XCTAssertEqual(try LifeStore(url: url).load(), state)
    }
    func testMissingFileStartsEmptyButCorruptFileThrowsAndIsPreserved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("life.json")
        let store = LifeStore(url: url)
        XCTAssertEqual(try store.load(), LifeState())
        let corrupt = Data("not json".utf8)
        try corrupt.write(to: url)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }
    func testDeletedItemsStayDeletedAndHabitHistoryCanBeCorrected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("life.json")
        var state = LifeState()
        state.notes = [Note(title: "Remove me")]
        state.habits = [Habit(name: "Read", completedDays: ["2026-09-05"])]
        try LifeStore(url: url).save(state)
        state.notes.removeAll()
        state.habits[0].completedDays.remove("2026-09-05")
        try LifeStore(url: url).save(state)
        XCTAssertTrue(try LifeStore(url: url).load().notes.isEmpty)
        XCTAssertTrue(try LifeStore(url: url).load().habits[0].completedDays.isEmpty)
    }
}
