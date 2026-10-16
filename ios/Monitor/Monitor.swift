// Runs in the background. Screen Time calls it at midnight and when the
// picked apps have been used for the daily limit.
import DeviceActivity

class Monitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity == .doitDay { Limit.newDay() }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if event == .doitLimit { Limit.lock() }
    }
}
