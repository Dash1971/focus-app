import Foundation
import FamilyControls

enum AppConstants {
    static let appGroup = "group.com.dash1971.focusapp"
    static let managedStore = "lockin.permanent"
    static let relockPrefix = "relock."
}

struct UnlockGrant: Codable {
    let id: UUID
    let selection: FamilyActivitySelection
    let deadline: UnlockDeadline
}

struct BlockingState: Codable {
    var selection = FamilyActivitySelection()
    var grant: UnlockGrant?
    var waitSeconds = 10
    // Retained only until old named stores have been cleared after an upgrade.
    var legacyStoreNames: [String] = []
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
