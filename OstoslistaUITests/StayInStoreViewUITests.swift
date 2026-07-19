import XCTest

/// Adding from the store view keeps the view open (R23): the search field
/// clears, the same store stays selected, and repeated adds work without
/// re-opening the sheet. Offline: uses the free-text path (Lidl has no
/// catalog), no network needed.
final class StayInStoreViewUITests: XCTestCase {
    func testAddingStaysInStoreView() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-UITestReset"]
        app.launch()

        let storefront = app.buttons["Hae kaupasta"]
        XCTAssertTrue(storefront.waitForExistence(timeout: 10)); storefront.tap()
        let picker = app.descendants(matching: .any).matching(identifier: "store-picker").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5)); picker.tap()
        let lidl = app.buttons["Lidl"].firstMatch
        XCTAssertTrue(lidl.waitForExistence(timeout: 5)); lidl.tap()

        let field = app.textFields["Tuotteen nimi"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("sipsit")
        app.buttons["Lisää listalle"].firstMatch.tap()

        // Still in the store view: picker present, field cleared, store kept.
        XCTAssertTrue(picker.waitForExistence(timeout: 5),
                      "store view must stay open after adding")
        XCTAssertEqual(field.value as? String, "Tuotteen nimi",
                       "search field must be empty (placeholder showing)")
        XCTAssertTrue(app.buttons["Lidl"].firstMatch.exists
                      || app.staticTexts["Lidl"].firstMatch.exists,
                      "same store must stay selected")

        // A second add works without reopening the sheet.
        field.tap()
        field.typeText("leipä")
        app.buttons["Lisää listalle"].firstMatch.tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        // Valmis closes the sheet; both items are on the main list.
        app.buttons["Valmis"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["sipsit"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["leipä"].firstMatch.waitForExistence(timeout: 5))
    }
}
