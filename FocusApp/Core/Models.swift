import Foundation
import FamilyControls

enum AppConstants {
    static let appGroup = "group.com.dash1971.focusapp"
    static let managedStore = "lockin.permanent"
    static let recoveryActivity = "lockin.recovery"
    static let relockPrefix = "relock."
    static let dailyActivityReport = "lockin.daily-activity"
}

struct UnlockGrant: Codable {
    let id: UUID
    let selection: FamilyActivitySelection
    let deadline: UnlockDeadline
}

struct UnlockRecord: Codable, Equatable {
    let id: UUID
    let startedAt: Date
    let scheduledEnd: Date
    var endedAt: Date?

    init(grant: UnlockGrant) {
        id = grant.id
        startedAt = grant.deadline.startedAt
        scheduledEnd = grant.deadline.endsAt
        endedAt = nil
    }

    func duration(during interval: DateInterval, now: Date = .now) -> TimeInterval {
        // Completed records use the observed relock time, including a delayed
        // system callback. Legacy orphan records without an end remain bounded.
        let finish = min(endedAt ?? min(now, scheduledEnd), now)
        let start = max(startedAt, interval.start)
        let end = min(finish, interval.end)
        return max(0, end.timeIntervalSince(start))
    }
}

struct BlockingState: Codable {
    var selection = FamilyActivitySelection()
    var grant: UnlockGrant?
    var waitSeconds = 10
    var unlockRecords: [UnlockRecord] = []
    // Retained only until old named stores have been cleared after an upgrade.
    var legacyStoreNames: [String] = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case selection, grant, waitSeconds, unlockRecords, legacyStoreNames
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        selection = try values.decodeIfPresent(FamilyActivitySelection.self, forKey: .selection) ?? .init()
        grant = try values.decodeIfPresent(UnlockGrant.self, forKey: .grant)
        waitSeconds = try values.decodeIfPresent(Int.self, forKey: .waitSeconds) ?? 10
        unlockRecords = try values.decodeIfPresent([UnlockRecord].self, forKey: .unlockRecords) ?? []
        legacyStoreNames = try values.decodeIfPresent([String].self, forKey: .legacyStoreNames) ?? []
    }

    var hasTemporaryAccess: Bool { grant.map { !$0.selection.isEmpty && $0.deadline.isActive() } ?? false }

    func canEditSettings(authorized: Bool) -> Bool {
        RestrictionAccessPolicy.canEdit(hasSelection: !selection.isEmpty, authorized: authorized, activeGrant: hasTemporaryAccess)
    }

    mutating func finishGrant(at date: Date = .now) {
        guard let grant else { return }
        if let index = unlockRecords.firstIndex(where: { $0.id == grant.id }) {
            let clamped = max(date, grant.deadline.startedAt)
            unlockRecords[index].endedAt = clamped
        }
        self.grant = nil
    }

    mutating func pruneUnlockRecords(now: Date = .now, calendar: Calendar = .current) {
        let cutoff = calendar.date(byAdding: .day, value: -32, to: now) ?? now.addingTimeInterval(-32 * 86_400)
        unlockRecords.removeAll { $0.scheduledEnd < cutoff }
    }

    func unlockActivity(on date: Date = .now, calendar: Calendar = .current) -> (count: Int, duration: TimeInterval) {
        guard let day = calendar.dateInterval(of: .day, for: date) else { return (0, 0) }
        let count = unlockRecords.filter { $0.startedAt >= day.start && $0.startedAt < day.end && $0.startedAt <= date }.count
        let duration = unlockRecords.reduce(0) { $0 + $1.duration(during: day, now: date) }
        return (count, duration)
    }
}

extension FamilyActivitySelection {
    var isEmpty: Bool { applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty }
    var itemCount: Int { applicationTokens.count + categoryTokens.count + webDomainTokens.count }

    func contains(_ other: Self) -> Bool {
        other.applicationTokens.isSubset(of: applicationTokens)
            && other.categoryTokens.isSubset(of: categoryTokens)
            && other.webDomainTokens.isSubset(of: webDomainTokens)
    }

    func subtracting(_ other: Self) -> Self {
        var result = self
        result.applicationTokens.subtract(other.applicationTokens)
        result.categoryTokens.subtract(other.categoryTokens)
        result.webDomainTokens.subtract(other.webDomainTokens)
        return result
    }
}

// Decode only the selection and store identities from v0.2.1. Challenges,
// session history and schedules have no role in the new blocking model.
struct LegacySnapshot: Decodable {
    struct LegacySession: Decodable { var selection: FamilyActivitySelection? }
    struct LegacySchedule: Decodable {
        var id: UUID
        var enabled: Bool
        var selection: FamilyActivitySelection?
    }
    var selection: FamilyActivitySelection?
    var activeSession: LegacySession?
    var schedules: [LegacySchedule]?

    func migrated() -> BlockingState {
        var result = BlockingState()
        result.selection = selection ?? .init()
        func include(_ chosen: FamilyActivitySelection?) {
            guard let chosen else { return }
            result.selection.applicationTokens.formUnion(chosen.applicationTokens)
            result.selection.categoryTokens.formUnion(chosen.categoryTokens)
            result.selection.webDomainTokens.formUnion(chosen.webDomainTokens)
        }
        include(activeSession?.selection)
        for schedule in schedules ?? [] where schedule.enabled { include(schedule.selection) }
        result.legacyStoreNames = ["focus.session"] + (schedules ?? []).map { "focus." + $0.id.uuidString }
        return result
    }
}
