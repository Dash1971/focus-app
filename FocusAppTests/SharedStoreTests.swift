import XCTest
import FamilyControls
@testable import LockIn

final class SharedStoreTests: XCTestCase {
    func testSeparateStoreInstancesSeeUpdatesAndFailedTransactionDoesNotWrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = SharedStore(directory: directory, legacyDefaults: nil)
        let second = SharedStore(directory: directory, legacyDefaults: nil)
        try first.transaction { $0.waitSeconds = 30 }
        XCTAssertEqual(try second.load().waitSeconds, 30)
        enum Failure: Error { case expected }
        XCTAssertThrowsError(try second.transaction { $0.waitSeconds = 60; throw Failure.expected })
        XCTAssertEqual(try first.load().waitSeconds, 30)
    }
    func testLegacyMigrationKeepsStoreIdentitiesWithoutImportingChallenges() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "test.lockin." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let id = UUID()
        let legacy: [String: Any] = ["schedules": [["id": id.uuidString, "enabled": true]], "challengesCompleted": 5]
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "sharedSnapshot.v1")
        let store = SharedStore(directory: directory, legacyDefaults: defaults)
        let migrated = try store.transaction { _ in }
        XCTAssertEqual(migrated.legacyStoreNames, ["focus.session", "focus." + id.uuidString])
        XCTAssertNil(migrated.grant)
        try store.transaction { $0.legacyStoreNames = [] }
        XCTAssertTrue(try store.load().legacyStoreNames.isEmpty)
        XCTAssertNotNil(defaults.data(forKey: "sharedSnapshot.v1")) // rollback copy remains
    }
    func testMissingAppGroupDoesNotSilentlyUseStandardDefaults() {
        XCTAssertThrowsError(try SharedStore(directory: nil, legacyDefaults: nil).load())
    }
    func testCorruptStateDoesNotBecomeEmptySelection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("blocking-state.v2.json")
        let data = Data("corrupt".utf8)
        try data.write(to: url)
        XCTAssertThrowsError(try SharedStore(directory: directory, legacyDefaults: nil).transaction { $0.waitSeconds = 60 })
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
    func testStateWrittenBeforeUnlockHistoryStillDecodes() throws {
        var state = BlockingState()
        state.waitSeconds = 45
        let encoded = try JSONEncoder().encode(state)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "unlockRecords")
        let restored = try JSONDecoder().decode(
            BlockingState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertEqual(restored.waitSeconds, 45)
        XCTAssertTrue(restored.unlockRecords.isEmpty)
    }
    func testUnlockActivityCountsStartsAndActualElapsedTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15))!
        let firstGrant = UnlockGrant(
            id: UUID(),
            selection: .init(),
            deadline: UnlockDeadline(seconds: 300, now: day.addingTimeInterval(60), uptime: 100)
        )
        let secondGrant = UnlockGrant(
            id: UUID(),
            selection: .init(),
            deadline: UnlockDeadline(seconds: 7200, now: day.addingTimeInterval(3600), uptime: 200)
        )
        var first = UnlockRecord(grant: firstGrant)
        first.endedAt = day.addingTimeInterval(180)
        let second = UnlockRecord(grant: secondGrant)
        var state = BlockingState()
        state.unlockRecords = [first, second]

        let activity = state.unlockActivity(on: day.addingTimeInterval(5400), calendar: calendar)
        XCTAssertEqual(activity.count, 2)
        XCTAssertEqual(activity.duration, 120 + 1800, accuracy: 0.001)
    }
}
