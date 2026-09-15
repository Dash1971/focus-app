import DeviceActivity
import Foundation
import OSLog

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        reconcile(activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        reconcile(activity)
    }

    private func reconcile(_ activity: DeviceActivityName) {
        // Old callbacks must never clear the new permanent store.
        guard activity.rawValue.hasPrefix(AppConstants.relockPrefix) || activity.rawValue == AppConstants.recoveryActivity else { return }
        do {
            try SharedStore.shared.transaction({ state in
                if let grant = state.grant, !grant.deadline.isActive() {
                    state.finishGrant()
                }
                do { try ShieldPolicy.refreshTokens(in: &state) }
                catch {
                    state.finishGrant()
                    Logger(subsystem: "com.dash1971.focusapp", category: "relock").error("Screen Time token refresh failed; restoring full saved shields.")
                }
                state.pruneUnlockRecords()
            }, afterSave: ShieldPolicy.apply)
        } catch {
            Logger(subsystem: "com.dash1971.focusapp", category: "relock").error("Relock state unavailable: \(error.localizedDescription, privacy: .public)")
            // Do not erase existing shields or replace unreadable state with defaults.
        }
    }
}
