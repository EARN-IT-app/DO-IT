// What the buttons on the "STOP." screen do. Apple doesn't let this screen open
// another app, so "DO IT" sends a notification that opens DO IT when tapped.
import ManagedSettings
import UserNotifications

class ShieldActions: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, done: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, done: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, done: completionHandler)
    }

    private func respond(to action: ShieldAction, done: @escaping (ShieldActionResponse) -> Void) {
        guard action == .primaryButtonPressed else { return done(.close) }
        let content = UNMutableNotificationContent()
        content.title = "DO IT"
        content.body = "Tap here to do your challenge."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "doit.open", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in done(.close) }
    }
}
