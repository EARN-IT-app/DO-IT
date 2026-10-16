// The "Time's up" screen iPhone shows in place of a blocked app.
import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfig: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { stop() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { stop() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { stop() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { stop() }

    private func stop() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: UIColor.black,
            icon: nil,
            title: .init(text: "TIME'S UP.", color: .white),
            subtitle: .init(
                text: "You used all your time on this today. It unlocks at midnight. Go DO IT.",
                color: UIColor(white: 0.82, alpha: 1)),
            primaryButtonLabel: .init(text: "Open DO IT", color: UIColor.black),
            primaryButtonBackgroundColor: UIColor(red: 0, green: 0.82, blue: 0.42, alpha: 1)
        )
    }
}
