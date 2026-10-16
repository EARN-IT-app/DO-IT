// Shared by the DO IT app and its three Screen Time extensions.
import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications

let appGroup = "group.io.github.wonderbread4912.doit"
let shared = UserDefaults(suiteName: appGroup) ?? .standard

/// The apps the person picked, and the Screen Time shield that blocks them.
enum Blocker {
    static let store = ManagedSettingsStore()

    static func load(_ key: String) -> FamilyActivitySelection? {
        guard let data = shared.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    static func save(_ value: FamilyActivitySelection?, _ key: String) {
        shared.set(value.flatMap { try? JSONEncoder().encode($0) }, forKey: key)
    }

    /// The apps being limited today.
    static var selection: FamilyActivitySelection {
        get { load("selection") ?? FamilyActivitySelection() }
        set { save(newValue, "selection") }
    }

    static func isEmpty(_ s: FamilyActivitySelection) -> Bool {
        s.applicationTokens.isEmpty && s.categoryTokens.isEmpty && s.webDomainTokens.isEmpty
    }

    static func shieldOn() {
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
    static let doitDay = Self("doit.day")
}

extension DeviceActivityEvent.Name {
    static let doitLimit = Self("doit.limit")
}

/// The daily limit. Screen Time counts how long the picked apps are used each day,
/// even when DO IT is closed. When the total reaches the limit, the apps are blocked
/// until midnight. Changes to the apps or the limit only start the next day,
/// so they can't be used to get back in today.
enum Limit {
    static let choices = [15, 30, 45, 60, 90, 120]

    static var minutes: Int {
        get { shared.integer(forKey: "limit") == 0 ? 30 : shared.integer(forKey: "limit") }
        set { shared.set(newValue, forKey: "limit") }
    }

    static var pendingMinutes: Int? {
        get { shared.object(forKey: "pendingLimit") as? Int }
        set { shared.set(newValue, forKey: "pendingLimit") }
    }

    static var pendingSelection: FamilyActivitySelection? {
        get { Blocker.load("pendingSelection") }
        set { Blocker.save(newValue, "pendingSelection") }
    }

    static var hasPending: Bool { pendingMinutes != nil || pendingSelection != nil }

    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    /// Whether today's time is used up.
    static var lockedToday: Bool { shared.string(forKey: "lockedDay") == dayKey() }

    /// Called when the limit is reached.
    static func lock() {
        shared.set(dayKey(), forKey: "lockedDay")
        Blocker.shieldOn()
        sendToDOIT(body: "Time's up for today. Tap here to open DO IT.")
    }

    /// iPhone doesn't let the Screen Time parts of an app open another app,
    /// so this sends a notification that opens DO IT when tapped.
    static func sendToDOIT(body: String) {
        let content = UNMutableNotificationContent()
        content.title = "DO IT"
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: "doit.open", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Called at the start of each day: unlock, apply any changes, and start counting again.
    static func newDay() {
        shared.set(nil, forKey: "lockedDay")
        Blocker.shieldOff()
        if let m = pendingMinutes { minutes = m; pendingMinutes = nil }
        if let s = pendingSelection { Blocker.selection = s; pendingSelection = nil }
        shared.set(dayKey(), forKey: "countingDay")
        try? startCounting()
    }

    static func startCounting() throws {
        let s = Blocker.selection
        let event = DeviceActivityEvent(
            applications: s.applicationTokens,
            categories: s.categoryTokens,
            webDomains: s.webDomainTokens,
            threshold: DateComponents(minute: minutes)
        )
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([.doitDay])
        try center.startMonitoring(.doitDay, during: schedule, events: [.doitLimit: event])
    }

    /// Backup for when the app opens on a new day before Screen Time caught up.
    static func checkDay() {
        if shared.string(forKey: "countingDay") != dayKey() { newDay() }
        else if lockedToday { Blocker.shieldOn() }
    }
}
