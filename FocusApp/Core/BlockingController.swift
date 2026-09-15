import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications

@MainActor
final class BlockingController {
    private let center = DeviceActivityCenter()
    private let shared = SharedStore.shared

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    func reconcile() throws -> BlockingState {
        // Persist and apply permanent protection BEFORE clearing legacy stores.
        let state = try shared.transaction({ state in
            if let grant = state.grant, !grant.deadline.isActive() {
                state.finishGrant(at: min(.now, grant.deadline.endsAt))
            }
            state.pruneUnlockRecords()
        }, afterSave: ShieldPolicy.apply)
        let obsolete = center.activities.filter { activity in
            activity.rawValue == "activeFocusSession" || activity.rawValue.hasPrefix("schedule.")
                || (activity.rawValue.hasPrefix(AppConstants.relockPrefix) && activity.rawValue != state.grant.map { AppConstants.relockPrefix + $0.id.uuidString })
        }
        center.stopMonitoring(obsolete)
        if !state.legacyStoreNames.isEmpty {
            for name in state.legacyStoreNames { ManagedSettingsStore(named: .init(name)).clearAllSettings() }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus.session", "normal.timer", "interval.timer"])
            return try shared.transaction { $0.legacyStoreNames = [] }
        }
        return state
    }

    func updateSelection(_ selection: FamilyActivitySelection) throws -> BlockingState {
        guard selection.applicationTokens.count <= 50, selection.webDomainTokens.count <= 50 else {
            throw BlockingError.tooManyItems
        }
        let state = try shared.transaction({ state in
            state.finishGrant()
            state.selection = selection
        }, afterSave: ShieldPolicy.apply)
        center.stopMonitoring(center.activities.filter { $0.rawValue.hasPrefix(AppConstants.relockPrefix) })
        return state
    }

    func lockNow() throws -> BlockingState {
        let state = try shared.transaction({ $0.finishGrant() }, afterSave: ShieldPolicy.apply)
        center.stopMonitoring(center.activities.filter { $0.rawValue.hasPrefix(AppConstants.relockPrefix) })
        return state
    }

    func unlock(_ selection: FamilyActivitySelection, seconds: Int) throws -> BlockingState {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { throw BlockingError.notAuthorized }
        guard TimePolicy.validDuration(seconds), !selection.isEmpty else { throw BlockingError.invalidRequest }
        let state = try shared.load()
        guard state.selection.contains(selection), state.grant == nil || state.grant?.deadline.isActive() == false else {
            throw BlockingError.invalidRequest
        }
        let grant = UnlockGrant(id: UUID(), selection: selection, deadline: UnlockDeadline(seconds: seconds))
        let activity = DeviceActivityName(AppConstants.relockPrefix + grant.id.uuidString)
        // Start a 16-minute monitoring interval AT the relock deadline. Relocking
        // happens in intervalDidStart, so a 30-second grant doesn't require an
        // unsupported 30-second DeviceActivity interval. End is a backup callback.
        let calendar = Calendar.current
        func components(_ date: Date) -> DateComponents {
            var value = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            value.calendar = calendar
            value.timeZone = calendar.timeZone
            return value
        }
        let start = Date(timeIntervalSince1970: ceil(grant.deadline.endsAt.timeIntervalSince1970))
        try center.startMonitoring(activity, during: DeviceActivitySchedule(
            intervalStart: components(start), intervalEnd: components(start.addingTimeInterval(16 * 60)), repeats: false))
        do {
            // Monitoring must succeed before a grant can remove any shield.
            return try shared.transaction({ current in
                guard current.selection.contains(selection), grant.deadline.isActive(),
                      current.grant == nil || current.grant?.deadline.isActive() == false else { throw BlockingError.invalidRequest }
                current.grant = grant
                current.unlockRecords.append(UnlockRecord(grant: grant))
                current.pruneUnlockRecords()
            }, afterSave: ShieldPolicy.apply)
        } catch {
            center.stopMonitoring([activity])
            throw error
        }
    }
}

enum BlockingError: LocalizedError {
    case invalidRequest, notAuthorized, tooManyItems
    var errorDescription: String? {
        switch self {
        case .invalidRequest: "Choose blocked items and one of the available durations up to 2 hours. Lock the current temporary access before requesting another."
        case .notAuthorized: "Allow Screen Time access before unlocking apps."
        case .tooManyItems: "Choose at most 50 individual apps and 50 websites. You can also select categories."
        }
    }
}
