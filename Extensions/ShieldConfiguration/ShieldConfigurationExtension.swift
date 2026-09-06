import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { makeConfiguration() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { makeConfiguration() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { makeConfiguration() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { makeConfiguration() }

    private func makeConfiguration() -> ShieldConfiguration {
        let subtitle = "This distraction stays locked. Close this app and open LockIn from your Home Screen for temporary access."
        let primary = "Close app"
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(white: 0.06, alpha: 1),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(text: "Locked by default", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .lightGray),
            primaryButtonLabel: ShieldConfiguration.Label(text: primary, color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Stay locked", color: .white)
        )
    }
}
