import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Supplies the words iOS draws on the shield (S7). Static on purpose: this extension runs under a tight memory limit.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private var daybreakShield: ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: UIColor.systemBackground.withAlphaComponent(0.55),
            icon: UIImage(systemName: "sunrise.fill"),
            title: ShieldConfiguration.Label(text: "Reflect first", color: .label),
            subtitle: ShieldConfiguration.Label(
                text: "Open Daybreak and write today's goals. This app unlocks for the day once they're approved.",
                color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.82, green: 0.54, blue: 0.13, alpha: 1),
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        daybreakShield
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        daybreakShield
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        daybreakShield
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        daybreakShield
    }
}
