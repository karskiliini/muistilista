import XCTest

/// R36: manual store-location picking, offline via UITEST_STORELOCATIONS.
final class StoreLocationUITests: XCTestCase {
    private var app: XCUIApplication!

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testPickStoreLocationManually() throws {
        app = XCUIApplication()
        app.launchArguments += ["-UITestReset"]
        app.launchEnvironment["UITEST_STORELOCATIONS"] =
            "708276035|S-market Kommila Varkaus|s-market|Savontie 44|Varkaus;"
            + "999|S-market Keskusta|s-market|Katu 1|Varkaus;"
            + "513971200|Prisma Mikkeli|prisma|Maaherrankatu 13|Mikkeli"
        app.launch()

        app.buttons["Hae kaupasta"].firstMatch.tap()
        let picker = element("store-picker")
        XCTAssertTrue(picker.waitForExistence(timeout: 5)); picker.tap()
        app.buttons["S-market"].firstMatch.tap()

        // Fixture mode skips auto-select → sheet opens by itself.
        let search = element("store-location-search")
        XCTAssertTrue(search.waitForExistence(timeout: 5), "picker sheet should auto-open")
        search.tap()

        // Brand filter check: "mikkeli" matches the Prisma fixture store by
        // name, so if the S-market chain filter broke, its row would appear.
        search.typeText("mikkeli")
        XCTAssertTrue(app.staticTexts["Ei osumia"].firstMatch.waitForExistence(timeout: 5),
                      "s-market chain must not surface Prisma stores")
        XCTAssertFalse(app.staticTexts["Prisma Mikkeli"].firstMatch.exists,
                        "brand filter must exclude other chains")
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))

        search.typeText("kommila")

        let kommila = app.staticTexts["S-market Kommila Varkaus"].firstMatch
        XCTAssertTrue(kommila.waitForExistence(timeout: 5), "fixture store should match")
        kommila.tap()

        // Sheet closes; the row remembers the choice; brand filter held
        // (Prisma fixture store must not appear for the S-market chain).
        XCTAssertFalse(search.waitForExistence(timeout: 2), "picker sheet should close after selection")

        let row = element("store-location-row")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["S-market Kommila Varkaus"].firstMatch
            .waitForExistence(timeout: 5))
    }
}
