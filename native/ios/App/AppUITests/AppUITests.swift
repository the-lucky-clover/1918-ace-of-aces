import XCTest

/// Minimal smoke test for the 1918 Capacitor wrapper.
/// Launches the app and proves the game actually loads by waiting for the
/// WKWebView (where the whole game renders) to appear on screen.
final class AppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Stop at the first failure so the error Steven copies back is clear.
        continueAfterFailure = false
    }

    func testAppLaunchesAndGameWebViewLoads() throws {
        let app = XCUIApplication()
        app.launch()

        // The game (title screen included) renders inside a single WKWebView.
        // Give it generous time: first launch on a fresh simulator is slow.
        let webView = app.webViews.firstMatch
        XCTAssertTrue(
            webView.waitForExistence(timeout: 30),
            "The game's web view never appeared — the title screen did not load."
        )

        // Attach a screenshot to the test report so a human can eyeball
        // that it really is the title screen and not a blank web view.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Title screen after launch"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
