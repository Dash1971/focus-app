import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { makeConfiguration() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { makeConfiguration() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { makeConfiguration() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { makeConfiguration() }

    private func makeConfiguration() -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(white: 0.06, alpha: 1),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(text: "This app is blocked.", color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Open LockIn", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Close app", color: .white)
        )
    }
}
