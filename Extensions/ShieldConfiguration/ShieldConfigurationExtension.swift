import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let snapshot = SharedStore.shared.load()
        let subtitle: String
        let primary: String

        if let session = snapshot.activeSession, session.endsAt > .now {
            subtitle = "Stay with what you chose. Available again at \(session.endsAt.formatted(date: .omitted, time: .shortened))."
            primary = session.challenge.kind == .none ? "Back to LockIn" : "Unlock Challenge"
        } else if let schedule = activeSchedule(in: snapshot.schedules) {
            subtitle = "\(schedule.name) is active. This app is blocked until \(schedule.endDate.formatted(date: .omitted, time: .shortened))."
            primary = schedule.challenge.kind == .none ? "Open LockIn" : "Unlock Challenge"
        } else {
            subtitle = "This app is unavailable during your current focus schedule."
            primary = "Open LockIn"
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.systemIndigo.withAlphaComponent(0.92),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(text: "LockIn is active", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor.white.withAlphaComponent(0.82)),
            primaryButtonLabel: ShieldConfiguration.Label(text: primary, color: .systemIndigo),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .white)
        )
    }

    private func activeSchedule(in schedules: [BlockSchedule]) -> BlockSchedule? {
        return schedules.first { schedule in
            schedule.enabled && ScheduleTiming.isActive(
                startMinutes: schedule.startMinutes,
                endMinutes: schedule.endMinutes,
                weekdays: schedule.weekdays
            )
        }
    }
}
