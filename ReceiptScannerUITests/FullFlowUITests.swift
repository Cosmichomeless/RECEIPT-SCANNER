import XCTest

/// Drives the real app through sample receipt -> review -> correct -> save -> history -> detail -> delete.
/// It expects an empty history: if an earlier run stopped before the delete step, reinstall the app first
/// (`xcrun simctl uninstall <device> dev.cosmichomeless.ReceiptScanner`).
final class FullFlowUITests: XCTestCase {
    private let shotDir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()

    private func shot(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: shotDir).appendingPathComponent("\(name).png"))
    }

    /// Form rows are lazy, so at large text sizes a field may need a scroll before it exists.
    @MainActor
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement) {
        for _ in 0..<6 where !element.exists || !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    @MainActor
    func testFullFlow() throws {
        let app = XCUIApplication()
        app.launch()
        shot("1-home")

        let more = app.buttons["More"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5), app.debugDescription)
        more.tap()
        shot("2-menu")
        app.buttons["Try sample receipt"].tap()

        XCTAssertTrue(app.navigationBars["Review"].waitForExistence(timeout: 20))
        shot("3-review")

        // The scan is shown, and scanning again is not offered mid-review.
        XCTAssertTrue(app.images["scanThumbnail"].exists || app.otherElements["scanThumbnail"].exists)
        XCTAssertFalse(app.buttons["Scan"].exists)
        XCTAssertFalse(more.exists)

        // The decimal pad has no return key, so it needs a Done button.
        let total = app.textFields["0.00"]
        scrollIntoView(app, total)
        total.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        shot("4-keyboard-done")
        done.tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)

        // Currency is chosen from a menu instead of typed.
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        let picker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Currency'")).firstMatch
        scrollIntoView(app, picker)
        picker.tap()
        shot("5-currency-menu")
        app.buttons["EUR"].tap()
        XCTAssertTrue(app.buttons["Save"].isEnabled)
        shot("6-currency-chosen")

        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["NORTHLINE HARDWARE"].waitForExistence(timeout: 10))
        shot("7-history")

        app.cells.firstMatch.tap()
        shot("8-detail")
        let delete = app.buttons["Delete receipt"]
        scrollIntoView(app, delete)
        delete.tap()
        XCTAssertTrue(app.staticTexts["No receipts yet"].waitForExistence(timeout: 5))
        shot("9-after-delete")
    }
}
