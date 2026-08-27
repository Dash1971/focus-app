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
            primary = session.challenge.kind == .none ? "Back to Focus" : "Unlock Challenge"
        } else if let schedule = activeSchedule(in: snapshot.schedules) {
            subtitle = "\(schedule.name) is active. This app is blocked until \(schedule.endDate.formatted(date: .omitted, time: .shortened))."
            primary = schedule.challenge.kind == .none ? "Open Focus" : "Unlock Challenge"
        } else {
            subtitle = "This app is unavailable during your current focus schedule."
            primary = "Open Focus"
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.systemIndigo.withAlphaComponent(0.92),
            icon: UIImage(systemName: "scope"),
            title: ShieldConfiguration.Label(text: "Focus is active", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor.white.withAlphaComponent(0.82)),
            primaryButtonLabel: ShieldConfiguration.Label(text: primary, color: .systemIndigo),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .white)
        )
    }

    private func activeSchedule(in schedules: [BlockSchedule]) -> BlockSchedule? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: .now)
        let minute = calendar.component(.hour, from: .now) * 60 + calendar.component(.minute, from: .now)
        return schedules.first { schedule in
            guard schedule.enabled else { return false }
            if schedule.endMinutes > schedule.startMinutes {
                return schedule.weekdays.contains(weekday) && minute >= schedule.startMinutes && minute < schedule.endMinutes
            }
            if minute >= schedule.startMinutes { return schedule.weekdays.contains(weekday) }
            let previousWeekday = weekday == 1 ? 7 : weekday - 1
            return minute < schedule.endMinutes && schedule.weekdays.contains(previousWeekday)
        }
    }
}
