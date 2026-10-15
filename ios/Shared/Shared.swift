// Shared by the DO IT app and its three Screen Time extensions.
import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

let appGroup = "group.io.github.wonderbread4912.doit"
let shared = UserDefaults(suiteName: appGroup) ?? .standard

/// The apps the person picked, and the Screen Time shield that blocks them.
enum Blocker {
    static let store = ManagedSettingsStore()

    static var selection: FamilyActivitySelection {
        get {
            guard let data = shared.data(forKey: "selection"),
                  let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
                return FamilyActivitySelection()
            }
            return saved
        }
        set { shared.set(try? JSONEncoder().encode(newValue), forKey: "selection") }
    }

    static var hasApps: Bool {
        let s = selection
        return !s.applicationTokens.isEmpty || !s.categoryTokens.isEmpty || !s.webDomainTokens.isEmpty
    }

    /// Block the picked apps (does nothing during a break).
    static func shieldOn() {
        guard !Break.active else { return }
        let s = selection
        store.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
        store.shield.applicationCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
        store.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
    }

    static func shieldOff() {
        store.clearAllSettings()
    }
}

extension DeviceActivityName {
    static let doitBreak = Self("doit.break")
}

/// A break lifts the shield, and Screen Time puts it back when the break ends,
/// even if DO IT is closed. Apple only allows timed windows of 15 minutes or more.
enum Break {
    static let minMinutes = 15
    static let maxMinutes = 60

    static var endsAt: Date {
        get { Date(timeIntervalSince1970: shared.double(forKey: "breakEnd")) }
        set { shared.set(newValue.timeIntervalSince1970, forKey: "breakEnd") }
    }

    static var active: Bool { endsAt > Date() }

    static func start(minutes asked: Int) throws {
        let minutes = min(max(asked, minMinutes), maxMinutes)
        let now = Date()
        let end = now.addingTimeInterval(Double(minutes) * 60)
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: now),
            intervalEnd: Calendar.current.dateComponents(parts, from: end),
            repeats: false
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([.doitBreak])
        try center.startMonitoring(.doitBreak, during: schedule)
        endsAt = end
        Blocker.shieldOff()
    }

    /// Called when the break window ends (by the Monitor extension, or by the app as a backup).
    static func end() {
        endsAt = .distantPast
        Blocker.shieldOn()
    }
}
