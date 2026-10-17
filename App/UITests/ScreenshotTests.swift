import XCTest

/// Captures the README and App Store screenshots. Each test launches the app
/// in a fixed state with `-mockFold`, so the images are reproducible.
///
/// Every screenshot is attached to the test result. When `SCREENSHOT_DIR` is
/// set (pass `TEST_RUNNER_SCREENSHOT_DIR` to xcodebuild), the PNGs are also
/// written there, named as in `docs/screenshots`.
final class ScreenshotTests: XCTestCase {
    static let question = "Should we drive down the coast this weekend?"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDuoOuterAsk() throws {
        let app = launch(fold: "closed")
        XCTAssertTrue(element(app, label: "Open your phone to reveal the answer.").waitForExistence(timeout: 10))
        try save("duo-outer-ask")
    }

    @MainActor
    func testDuoHalfOpen() throws {
        let app = launch(fold: "half")
        // Only the opening screen shows the question as text. The ask
        // screen has it inside the text field.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", Self.question)).firstMatch.waitForExistence(timeout: 10))
        try save("duo-half-open")
    }

    @MainActor
    func testDuoInnerReveal() throws {
        let app = launch(fold: "open")
        XCTAssertTrue(app.buttons["Ask again"].waitForExistence(timeout: 10))
        try save("duo-inner-reveal")
    }

    @MainActor
    func testIPhoneTapReveal() throws {
        let app = launch(fold: "tap")
        let reveal = app.buttons["Reveal"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Answers"].exists, "the Answers toolbar button is missing")
        reveal.tap()
        XCTAssertTrue(app.buttons["Ask again"].waitForExistence(timeout: 10))
        try save("iphone-tap-reveal")
    }

    @MainActor
    private func launch(fold: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-mockFold", fold, "-mockQuestion", Self.question]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    @MainActor
    private func save(_ name: String) throws {
        // Let the pod spring and the reveal fade settle.
        Thread.sleep(forTimeInterval: 1.5)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty else { return }
        let folder = URL(fileURLWithPath: dir, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
    }
}
