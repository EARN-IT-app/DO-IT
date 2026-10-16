// Runs in the background. Screen Time calls it at midnight, when focus mode or
// bedtime starts and ends, and as the picked apps get used during the day.
import DeviceActivity

class Monitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity == .doitDay { Limit.newDay() }
        else if activity == .doitFocus { Blocker.shieldOn(.focus) }
        else if Bedtime.isBedtime(activity) { Bedtime.refresh() }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == .doitFocus { Focus.end() }
        else if Bedtime.isBedtime(activity) { Bedtime.refresh() }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if event == .doitLimit {
            Limit.lock()
        } else if event.rawValue.hasPrefix("doit.used."), let m = Int(event.rawValue.dropFirst(10)) {
            Limit.recordUsed(m)
        }
    }
}
