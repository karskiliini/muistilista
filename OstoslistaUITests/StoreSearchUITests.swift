import XCTest

/// Live end-to-end check that the Gigantti store search works: it drives the
/// store-add flow (open search → pick Gigantti → type a query) and asserts real
/// results appear. Gigantti runs through a WKWebView (Vercel bot challenge) +
/// Algolia, so this needs network and a warm-up; timeouts are generous.
final class StoreSearchUITests: XCTestCase {
    func testGiganttiSearchReturnsResults() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-UITestReset"]
        app.launch()

        // Open the store-search sheet.
        let storefront = app.buttons["Hae kaupasta"]
        XCTAssertTrue(storefront.waitForExistence(timeout: 10), "storefront button missing")
        storefront.tap()

        // Pick Gigantti from the store dropdown.
        let picker = app.descendants(matching: .any).matching(identifier: "store-picker").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "store picker missing")
        picker.tap()
        let gigantti = app.buttons["Gigantti"]
        XCTAssertTrue(gigantti.waitForExistence(timeout: 5), "Gigantti option missing")
        gigantti.tap()

        // Type a query that definitely has hits.
        let field = app.textFields["Hae kaupasta…"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "search field missing")
        field.tap()
        field.typeText("kahvinkeitin")

        // A price (contains "€") should appear once the engine warms up and the
        // Algolia query returns — allow generous time for the bot challenge.
        let priceCell = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "€")).firstMatch
        XCTAssertTrue(priceCell.waitForExistence(timeout: 40),
                      "Gigantti returned no results (engine/challenge/network?)")
        XCTAssertFalse(app.staticTexts["Ei osumia"].exists, "showed 'Ei osumia'")
    }
}
