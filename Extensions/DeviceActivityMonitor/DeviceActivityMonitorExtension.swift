import DeviceActivity
import ManagedSettings
import Foundation
import FamilyControls

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let snapshot = SharedStore.shared.load()

        if activity.rawValue == AppConstants.focusActivity {
            let store = ManagedSettingsStore(named: .init(AppConstants.managedStorePrefix + "session"))
            if let chosen = snapshot.activeSession?.selection, !chosen.isEmpty {
                apply(chosen, to: store)
            } else {
                apply(snapshot.selection, to: store)
            }
            return
        }

        guard activity.rawValue.hasPrefix(AppConstants.schedulePrefix),
              let id = UUID(uuidString: String(activity.rawValue.dropFirst(AppConstants.schedulePrefix.count))),
              let schedule = snapshot.schedules.first(where: { $0.id == id && $0.enabled }) else { return }

        let store = ManagedSettingsStore(named: .init(AppConstants.managedStorePrefix + id.uuidString))
        guard ScheduleTiming.isActive(
            startMinutes: schedule.startMinutes,
            endMinutes: schedule.endMinutes,
            weekdays: schedule.weekdays
        ) else {
            store.clearAllSettings()
            return
        }
        apply(schedule.selection.isEmpty ? snapshot.selection : schedule.selection, to: store)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        if activity.rawValue == AppConstants.focusActivity {
            ManagedSettingsStore(named: .init(AppConstants.managedStorePrefix + "session")).clearAllSettings()
            SharedStore.shared.mutate { snapshot in
                guard let session = snapshot.activeSession else { return }
                if !snapshot.records.contains(where: { $0.id == session.id }) {
                    snapshot.records.append(.init(
                        id: session.id,
                        startedAt: session.startedAt,
                        endedAt: .now,
                        plannedMinutes: session.plannedMinutes,
                        completed: true,
                        emergencyUnlock: false
                    ))
                }
                snapshot.activeSession = nil
            }
            return
        }

        guard activity.rawValue.hasPrefix(AppConstants.schedulePrefix),
              let id = UUID(uuidString: String(activity.rawValue.dropFirst(AppConstants.schedulePrefix.count))) else { return }
        ManagedSettingsStore(named: .init(AppConstants.managedStorePrefix + id.uuidString)).clearAllSettings()
    }

    private func apply(_ selection: FamilyActivitySelection, to store: ManagedSettingsStore) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }
}

private extension FamilyActivitySelection {
    var isEmpty: Bool { applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty }
}
