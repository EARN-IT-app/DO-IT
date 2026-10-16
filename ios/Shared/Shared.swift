// Shared by the DO IT app and its three Screen Time extensions.
import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications

let appGroup = "group.io.github.wonderbread4912.doit"
let shared = UserDefaults(suiteName: appGroup) ?? .standard

/// Why the apps are blocked. Each reason has its own Screen Time store,
/// so one ending (like a focus session) doesn't unblock another (like the daily limit).
enum Reason: String {
    case limit, focus, bedtime
}

/// The apps the person picked, and the Screen Time shields that block them.
enum Blocker {
    static func store(_ reason: Reason) -> ManagedSettingsStore {
        ManagedSettingsStore(named: .init(reason.rawValue))
    }

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

    static func shieldOn(_ reason: Reason) {
        let s = selection
        let store = store(reason)
        store.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
        store.shield.applicationCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
        store.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
    }

    static func shieldOff(_ reason: Reason) {
        store(reason).clearAllSettings()
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
}

extension DeviceActivityName {
    static let doitDay = Self("doit.day")
    static let doitFocus = Self("doit.focus")
    static let doitBedtime = Self("doit.bedtime")
}

extension DeviceActivityEvent.Name {
    static let doitLimit = Self("doit.limit")
    /// "doit.used.5", "doit.used.10" and so on: how DO IT knows roughly how much time is used.
    static func used(_ minutes: Int) -> Self { Self("doit.used.\(minutes)") }
}

func dayKey(_ date: Date = Date()) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return "\(c.year!)-\(c.month!)-\(c.day!)"
}

/// The daily limit. Screen Time counts how long the picked apps are used each day,
/// even when DO IT is closed. When the total reaches the limit, the apps are blocked
/// until midnight. The limit is fixed, and changes to the apps only start the next
/// day, so neither can be used to get back in today.
enum Limit {
    static let minutes = 30
    static let step = 5

    static var pendingSelection: FamilyActivitySelection? {
        get { Blocker.load("pendingSelection") }
        set { Blocker.save(newValue, "pendingSelection") }
    }

    static var hasPending: Bool { pendingSelection != nil }

    /// Whether today's time is used up.
    static var lockedToday: Bool { shared.string(forKey: "lockedDay") == dayKey() }

    /// Minutes used today, in steps of 5.
    static var usedToday: Int {
        if lockedToday { return minutes }
        return shared.string(forKey: "usedDay") == dayKey() ? shared.integer(forKey: "used") : 0
    }

    static func recordUsed(_ m: Int) {
        guard m > usedToday else { return }
        shared.set(dayKey(), forKey: "usedDay")
        shared.set(m, forKey: "used")
    }

    /// Days in a row the limit wasn't reached.
    static var streak: Int { shared.integer(forKey: "streak") }

    /// Called when the limit is reached.
    static func lock() {
        shared.set(dayKey(), forKey: "lockedDay")
        Blocker.shieldOn(.limit)
        Blocker.sendToDOIT(body: "Time's up for today. Tap here to open DO IT.")
    }

    /// Called at the start of each day: count the streak, unlock, apply any app
    /// changes, and start counting again.
    static func newDay() {
        let yesterday = dayKey(Date().addingTimeInterval(-86400))
        if shared.string(forKey: "countingDay") == yesterday {
            let failed = shared.string(forKey: "lockedDay") == yesterday
            shared.set(failed ? 0 : streak + 1, forKey: "streak")
        } else if shared.string(forKey: "countingDay") != dayKey() {
            shared.set(0, forKey: "streak") // DO IT wasn't running: start over
        }
        shared.set(nil, forKey: "lockedDay")
        Blocker.shieldOff(.limit)
        if let s = pendingSelection { Blocker.selection = s; pendingSelection = nil }
        shared.set(dayKey(), forKey: "countingDay")
        try? startCounting()
        Bedtime.refresh()
    }

    static func startCounting() throws {
        let s = Blocker.selection
        func event(_ m: Int) -> DeviceActivityEvent {
            DeviceActivityEvent(applications: s.applicationTokens, categories: s.categoryTokens,
                                webDomains: s.webDomainTokens, threshold: DateComponents(minute: m))
        }
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [.doitLimit: event(minutes)]
        for m in stride(from: step, to: minutes, by: step) { events[.used(m)] = event(m) }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([.doitDay])
        try center.startMonitoring(.doitDay, during: schedule, events: events)
    }

    /// Backup for when the app opens on a new day before Screen Time caught up.
    static func checkDay() {
        if shared.string(forKey: "countingDay") != dayKey() { newDay() }
        else if lockedToday { Blocker.shieldOn(.limit) }
        Focus.check()
        Bedtime.refresh()
    }
}

/// Focus mode: block the apps right now for a set time. It can't be cancelled.
/// Apple only allows timed windows of 15 minutes or more.
enum Focus {
    static let choices = [15, 30, 60, 120]

    static var endsAt: Date {
        get { Date(timeIntervalSince1970: shared.double(forKey: "focusEnd")) }
        set { shared.set(newValue.timeIntervalSince1970, forKey: "focusEnd") }
    }

    static var active: Bool { endsAt > Date() }

    static func start(minutes: Int) throws {
        let now = Date()
        let end = now.addingTimeInterval(Double(max(minutes, 15)) * 60)
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: now),
            intervalEnd: Calendar.current.dateComponents(parts, from: end),
            repeats: false
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([.doitFocus])
        try center.startMonitoring(.doitFocus, during: schedule)
        endsAt = end
        Blocker.shieldOn(.focus)
    }

    static func end() {
        endsAt = .distantPast
        Blocker.shieldOff(.focus)
        Blocker.sendToDOIT(body: "Focus done. Nice work.")
    }

    /// Backup in case the end was missed.
    static func check() {
        if active { Blocker.shieldOn(.focus) }
        else if shared.double(forKey: "focusEnd") > 0 { endsAt = .distantPast; Blocker.shieldOff(.focus) }
    }
}

/// Bedtime lock: the apps are blocked every night from 10 PM to 7 AM.
/// It can only be turned off during the day, so it can't be used to get back in at night.
enum Bedtime {
    static let startHour = 22
    static let endHour = 7

    static var on: Bool {
        get { shared.bool(forKey: "bedtimeOn") }
        set { shared.set(newValue, forKey: "bedtimeOn") }
    }

    static var isNight: Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= startHour || h < endHour
    }

    static func turnOn() throws {
        // Two windows, because a Screen Time window can't cross midnight.
        let center = DeviceActivityCenter()
        center.stopMonitoring([.doitBedtime])
        try center.startMonitoring(.doitBedtime, during: DeviceActivitySchedule(
            intervalStart: DateComponents(hour: startHour, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true))
        try center.startMonitoring(.init("doit.bedtime.morning"), during: DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: endHour, minute: 0),
            repeats: true))
        on = true
        refresh()
    }

    static func turnOff() {
        guard !isNight else { return }
        DeviceActivityCenter().stopMonitoring([.doitBedtime, .init("doit.bedtime.morning")])
        on = false
        Blocker.shieldOff(.bedtime)
    }

    /// Block or unblock to match the clock.
    static func refresh() {
        if on && isNight { Blocker.shieldOn(.bedtime) } else { Blocker.shieldOff(.bedtime) }
    }

    static func isBedtime(_ activity: DeviceActivityName) -> Bool {
        activity == .doitBedtime || activity.rawValue == "doit.bedtime.morning"
    }
}
