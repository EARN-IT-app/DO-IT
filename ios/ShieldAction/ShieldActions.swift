// What the button on the "Time's up" screen does: it sends a notification that
// opens DO IT (iPhone doesn't let this screen open DO IT directly), then closes the app.
import ManagedSettings

class ShieldActions: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        Limit.sendToDOIT(body: "Tap here to open DO IT.")
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        Limit.sendToDOIT(body: "Tap here to open DO IT.")
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        Limit.sendToDOIT(body: "Tap here to open DO IT.")
        completionHandler(.close)
    }
}
