// Runs in the background when a break's time window ends, and blocks the apps again.
import DeviceActivity

class Monitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == .doitBreak { Break.end() }
    }
}
