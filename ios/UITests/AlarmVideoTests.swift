// Drives the test iPhone while GitHub records the screen: allow alarms, go to the
// home screen, wait for the alarm to go off, then tap its only button.
import XCTest

final class AlarmVideoTests: XCTestCase {
    func testAlarmGoesOff() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-demoRingSoon"]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 15) { allow.tap() }
        sleep(4)
        XCUIDevice.shared.press(.home)

        // The alarm rings at the start of the next minute (or the one after).
        let button = springboard.buttons["Mirror photo"]
        XCTAssertTrue(button.waitForExistence(timeout: 120), "The alarm didn't go off")
        sleep(6)
        button.tap()
        sleep(15)
    }
}
