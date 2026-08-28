import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Combine

@MainActor
final class BlockingController: ObservableObject {
    static let shared = BlockingController()

    private let center = DeviceActivityCenter()
    private let store = ManagedSettingsStore(named: .init(AppConstants.managedStorePrefix + "session"))

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    func apply(selection: FamilyActivitySelection, to store: ManagedSettingsStore) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    func startFocus(selection: FamilyActivitySelection, minutes: Int) throws -> ActiveFocusSession {
        let safeMinutes = max(1, minutes)
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(safeMinutes * 60))
        let calendar = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        center.stopMonitoring([.focusSession])
        try center.startMonitoring(.focusSession, during: schedule)
        apply(selection: selection, to: store)
        return ActiveFocusSession(id: UUID(), startedAt: now, endsAt: end, plannedMinutes: safeMinutes, challenge: .init())
    }

    func clearFocus() {
        store.clearAllSettings()
        center.stopMonitoring([.focusSession])
    }

    func install(_ schedule: BlockSchedule, selection: FamilyActivitySelection) throws {
        let calendar = Calendar.current
        let start = DateComponents(hour: schedule.startMinutes / 60, minute: schedule.startMinutes % 60)
        let end = DateComponents(hour: schedule.endMinutes / 60, minute: schedule.endMinutes % 60)
        let activity = DeviceActivityName.schedule(schedule.id)
        center.stopMonitoring([activity])
        guard schedule.enabled else {
            ManagedSettingsStore(named: .init(AppConstants.managedStorePrefix + schedule.id.uuidString)).clearAllSettings()
            return
        }
        try center.startMonitoring(activity, during: DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true))

        // If the schedule is active now, apply it without waiting for the next callback.
        let weekday = calendar.component(.weekday, from: .now)
        let minute = calendar.component(.hour, from: .now) * 60 + calendar.component(.minute, from: .now)
        let crossesMidnight = schedule.endMinutes <= schedule.startMinutes
        let activeTime = crossesMidnight ? (minute >= schedule.startMinutes || minute < schedule.endMinutes) : (minute >= schedule.startMinutes && minute < schedule.endMinutes)
        let applicableWeekday = crossesMidnight && minute < schedule.endMinutes ? (weekday == 1 ? 7 : weekday - 1) : weekday
        if schedule.weekdays.contains(applicableWeekday), activeTime {
            apply(selection: selection, to: ManagedSettingsStore(named: .init(AppConstants.managedStorePrefix + schedule.id.uuidString)))
        }
    }

    func remove(_ schedule: BlockSchedule) {
        center.stopMonitoring([.schedule(schedule.id)])
        ManagedSettingsStore(named: .init(AppConstants.managedStorePrefix + schedule.id.uuidString)).clearAllSettings()
    }
}
