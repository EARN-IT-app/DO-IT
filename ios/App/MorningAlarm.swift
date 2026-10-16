// The morning alarm. It rings every minute for half an hour and only stops
// for good once you take a photo of yourself in the mirror in DO IT. There's no
// snooze: the alarm's only button opens DO IT on the mirror photo screen.
// On iOS 26 and later it uses real alarms (AlarmKit), which ring even on silent.
// On older iPhones it falls back to loud notifications.
import SwiftUI
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
import AppIntents
#endif

enum MorningAlarm {
    /// Rings at the set time, then again every `gap` minutes, `rings` times in all.
    static let rings = 30
    static let gap = 1
    static var windowMinutes: Int { rings * gap }
    /// Alarms are set up this many days ahead, and topped up whenever DO IT opens.
    /// (Two days of rings fits under iPhone's limit of 64 waiting notifications.)
    static let daysAhead = 2

    static var on: Bool {
        get { shared.bool(forKey: "alarmOn") }
        set { shared.set(newValue, forKey: "alarmOn") }
    }

    static var hour: Int {
        get { shared.object(forKey: "alarmHour") as? Int ?? 7 }
        set { shared.set(newValue, forKey: "alarmHour") }
    }

    static var minute: Int {
        get { shared.integer(forKey: "alarmMinute") }
        set { shared.set(newValue, forKey: "alarmMinute") }
    }

    static var time: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    /// The mirror photo was taken today.
    static var doneToday: Bool { shared.string(forKey: "alarmDoneDay") == dayKey() }

    /// The alarm is going off right now and hasn't been stopped with a photo.
    static var ringing: Bool {
        if CommandLine.arguments.contains("-demoAlarm") { return true }
        guard on, !doneToday else { return false }
        let now = Date()
        return now >= time && now < time.addingTimeInterval(Double(windowMinutes) * 60)
    }

    /// Every ring from today (or tomorrow, once today's is done) for the next few days.
    static func ringTimes() -> [Date] {
        var times: [Date] = []
        let cal = Calendar.current
        for day in 0..<daysAhead {
            if day == 0 && doneToday { continue }
            guard let date = cal.date(byAdding: .day, value: day, to: Date()),
                  let start = cal.date(bySettingHour: hour, minute: minute, second: 0, of: date) else { continue }
            for i in 0..<rings {
                let t = start.addingTimeInterval(Double(i * gap) * 60)
                if t > Date() { times.append(t) }
            }
        }
        return times
    }

    /// Clear every ring that's set up, and set up the ones still to come.
    static func reschedule() async {
        let times = on ? ringTimes() : []
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            if await RealAlarms.schedule(times) { return }
        }
        #endif
        scheduleNotifications(times)
    }

    static func photoTaken() async {
        shared.set(dayKey(), forKey: "alarmDoneDay")
        await reschedule()
    }

    private static func scheduleNotifications(_ times: [Date]) {
        let center = UNUserNotificationCenter.current()
        let old = (0..<(rings * daysAhead)).map { "doit.alarm.\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: old)
        center.removeDeliveredNotifications(withIdentifiers: old)
        for (i, t) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "WAKE UP"
            content.body = "Open DO IT and take a photo of yourself in the mirror to stop the alarm."
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: t)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: "doit.alarm.\(i)", content: content, trigger: trigger))
        }
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct DOITAlarmInfo: AlarmMetadata {}

/// The alarm's only button: opens DO IT on the mirror photo screen. Apple requires
/// a button that quiets the alarm, so this one also opens DO IT, where the video
/// plays, and the alarm rings again a minute later until the photo is taken.
@available(iOS 26.0, *)
struct OpenMirrorPhoto: LiveActivityIntent {
    static var title: LocalizedStringResource = "Take the mirror photo"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult { .result() }
}

@available(iOS 26.0, *)
enum RealAlarms {
    /// Returns false if alarms aren't allowed, so notifications are used instead.
    static func schedule(_ times: [Date]) async -> Bool {
        let manager = AlarmManager.shared
        // Only ask for alarm permission once the alarm is turned on.
        if times.isEmpty {
            for alarm in (try? manager.alarms) ?? [] { try? manager.cancel(id: alarm.id) }
            return manager.authorizationState == .authorized
        }
        if manager.authorizationState == .notDetermined {
            _ = try? await manager.requestAuthorization()
        }
        guard manager.authorizationState == .authorized else { return false }
        for alarm in (try? manager.alarms) ?? [] { try? manager.cancel(id: alarm.id) }

        let alert = AlarmPresentation.Alert(
            title: "WAKE UP. Mirror photo to stop it.",
            stopButton: AlarmButton(text: "Mirror photo", textColor: .white, systemImageName: "camera.fill")
        )
        let attributes = AlarmAttributes<DOITAlarmInfo>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: Color(red: 0, green: 0.82, blue: 0.42)
        )
        for t in times {
            let config = AlarmManager.AlarmConfiguration<DOITAlarmInfo>(
                schedule: .fixed(t),
                attributes: attributes,
                stopIntent: OpenMirrorPhoto()
            )
            _ = try? await manager.schedule(id: UUID(), configuration: config)
        }
        return true
    }
}
#endif
