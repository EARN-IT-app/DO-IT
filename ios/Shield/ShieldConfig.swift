// The screen iPhone shows in place of a blocked app: why it's blocked,
// plus a different push to get moving each time.
import ManagedSettings
import ManagedSettingsUI
import UIKit

let quotes = [
    "Don't let your dreams be dreams. Just do it.",
    "You don't need more time. You need to start.",
    "The phone will still be here later. This moment won't.",
    "Small steps every day add up.",
    "Done is better than perfect.",
    "Future you is watching. Make them proud.",
    "Discipline is choosing what you want most over what you want now.",
    "Start before you feel ready.",
    "You've scrolled enough today. Go build something.",
    "One hour of focus beats a day of distraction.",
]

class ShieldConfig: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { stop() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { stop() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { stop() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { stop() }

    private func stop() -> ShieldConfiguration {
        let title: String
        let why: String
        if Focus.active {
            let f = DateFormatter(); f.timeStyle = .short
            title = "FOCUS MODE."
            why = "Locked until \(f.string(from: Focus.endsAt))."
        } else if Bedtime.on && Bedtime.isNight {
            title = "BEDTIME."
            why = "Locked until 7 AM. Put the phone down and sleep."
        } else {
            title = "TIME'S UP."
            why = "You used your \(Limit.minutes) minutes today. It unlocks at midnight."
        }
        return ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: UIColor.black,
            icon: nil,
            title: .init(text: title, color: .white),
            subtitle: .init(
                text: Settings.quotes ? why + "\n\n\"" + (quotes.randomElement() ?? quotes[0]) + "\"" : why,
                color: UIColor(white: 0.82, alpha: 1)),
            primaryButtonLabel: .init(text: "Open DO IT", color: UIColor.black),
            primaryButtonBackgroundColor: UIColor(red: 0, green: 0.82, blue: 0.42, alpha: 1)
        )
    }
}
