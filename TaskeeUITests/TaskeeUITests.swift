import XCTest

final class TaskeeScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true

        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            for title in ["OK", "Allow", "Don't Allow", "Continue", "Not Now", "Cancel", "Later"] {
                let button = alert.buttons[title]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }

    private func launchApp(role: String, screen: String = "dashboard") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotMode", "-screenshotRole", role, "-screenshotScreen", screen]
        app.launch()
        Thread.sleep(forTimeInterval: 8)
        return app
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testParentDashboard() throws {
        _ = launchApp(role: "parent")
        saveScreenshot("01_Parent_Dashboard")
    }

    @MainActor
    func testParentFamilyChat() throws {
        _ = launchApp(role: "parent", screen: "chat")
        saveScreenshot("02_Family_Chat")
    }

    @MainActor
    func testChildDashboard() throws {
        _ = launchApp(role: "child")
        saveScreenshot("03_Child_Dashboard")
    }

    @MainActor
    func testChildFamilyChat() throws {
        _ = launchApp(role: "child", screen: "chat")
        saveScreenshot("04_Child_Family_Chat")
    }
}
