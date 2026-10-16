// Drives the test iPhone through the app while GitHub records the screen:
// the setup screen, each tab, stretches and the alarm.
import XCTest

final class WalkthroughTests: XCTestCase {
    func tap(_ el: XCUIElement) { if el.waitForExistence(timeout: 4) { el.tap() } }

    func testWalkthrough() throws {
        let app = XCUIApplication()
        app.launch() // first time: the setup screen
        sleep(4)
        app.terminate()

        app.launchArguments = ["-demo"]
        app.launch()
        sleep(4)
        for _ in 0..<7 { app.swipeUp(velocity: .slow); sleep(2) }
        for _ in 0..<8 { app.swipeDown(velocity: .fast) }
        sleep(2)

        // Visit each tab, then open stretches from the Me tab.
        for tab in ["Focus", "Week", "Me"] {
            tap(app.tabBars.buttons[tab])
            sleep(3)
        }
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Stretch")).firstMatch)
        sleep(3)
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Start stretching")).firstMatch)
        sleep(6)
        tap(app.buttons["Close"])
        sleep(2)
        tap(app.tabBars.buttons["Today"])
        sleep(2)
        app.terminate()

        app.launchArguments = ["-demo", "-demoAlarm"]
        app.launch()
        sleep(10)
    }
}
