import XCTest

/// Drives the store drag-and-drop with faked press-then-slide gestures in the
/// Simulator, so its data outcomes are proven here instead of by shipping and
/// asking the user to test on-device. These verify WHERE items land (store and
/// order) and that catalog items stay locked; the live feel is a visual matter
/// the user confirms on device. Store fixtures are seeded via UITEST_ITEMS so
/// the tests don't depend on the (removed) ⋯ menu or live catalogs.
final class DragMoveUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestReset"]
    }

    /// Launch, optionally pre-seeding items ("name|store|opt;..." — empty store
    /// = no store, opt "cat" = catalog/store-bound).
    private func launch(seed: String = "") {
        if !seed.isEmpty { app.launchEnvironment["UITEST_ITEMS"] = seed }
        app.launch()
    }

    /// Any element with the given identifier, regardless of type.
    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func addFreeItem(_ name: String) {
        let field = app.textFields["Lisää tuote…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Add field missing")
        field.tap()
        field.typeText("\(name)\n")
    }

    /// Dragging a free item onto another store's section moves it there.
    func testDragFreeItemOntoStoreGroupMovesIt() throws {
        launch(seed: "maito|Prisma")
        addFreeItem("sokeri")

        let maitoStore = element("store-maito")
        XCTAssertTrue(maitoStore.waitForExistence(timeout: 5), "seed failed")
        XCTAssertEqual(maitoStore.label, "Prisma")
        XCTAssertFalse(element("store-sokeri").exists, "sokeri should start store-less")

        let handle = element("handle-sokeri")
        XCTAssertTrue(handle.waitForExistence(timeout: 5), "sokeri drag handle missing")
        handle.press(forDuration: 1.0, thenDragTo: maitoStore)

        let sokeriStore = element("store-sokeri")
        XCTAssertTrue(sokeriStore.waitForExistence(timeout: 5),
                      "sokeri never gained a store (debug: \(element("debug-drop").label))")
        XCTAssertEqual(sokeriStore.label, "Prisma", "sokeri did not move to Prisma")
    }

    /// Dragging an item within its own group reorders it. Dropped at the
    /// bottom, it becomes last.
    func testDragReordersWithinGroup() throws {
        launch()
        addFreeItem("alfa")
        addFreeItem("beeta")
        addFreeItem("gamma")

        let alfa = element("handle-alfa")
        let beeta = element("handle-beeta")
        let gamma = element("handle-gamma")
        XCTAssertTrue(alfa.waitForExistence(timeout: 10))
        XCTAssertTrue(gamma.waitForExistence(timeout: 5))

        XCTAssertLessThan(alfa.frame.minY, beeta.frame.minY, "alfa should start above beeta")
        XCTAssertLessThan(beeta.frame.minY, gamma.frame.minY, "beeta should start above gamma")

        let bottom = element("debug-drop")
        XCTAssertTrue(bottom.waitForExistence(timeout: 5))
        alfa.press(forDuration: 1.0, thenDragTo: bottom)

        XCTAssertLessThan(beeta.frame.minY, gamma.frame.minY, "beeta should stay above gamma")
        XCTAssertLessThan(gamma.frame.minY, alfa.frame.minY,
                          "alfa should now be last (debug: \(bottom.label))")
    }

    /// A stored item dragged to the bottom lands in the always-available
    /// "Ei kauppaa" zone and loses its store.
    func testDragToNoStoreClearsStore() throws {
        launch(seed: "maito|Prisma")
        let maitoStore = element("store-maito")
        XCTAssertTrue(maitoStore.waitForExistence(timeout: 5))
        XCTAssertEqual(maitoStore.label, "Prisma")

        let handle = element("handle-maito")
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        handle.press(forDuration: 1.0, thenDragTo: element("debug-drop"))

        XCTAssertFalse(element("store-maito").waitForExistence(timeout: 3),
                       "maito should have lost its store (debug: \(element("debug-drop").label))")
    }

    /// A catalog item can be reordered (it has a handle) but must NOT move to
    /// another store — dragging it onto another store's section leaves it put.
    func testCatalogItemStaysInOwnStore() throws {
        launch(seed: "ruuvi|K-Rauta|cat;maito|Prisma")

        let ruuviStore = element("store-ruuvi")
        XCTAssertTrue(ruuviStore.waitForExistence(timeout: 5), "ruuvi not shown")
        XCTAssertTrue(ruuviStore.label.contains("K-Rauta"), "setup: ruuvi in K-Rauta")

        // It has a handle (reorder allowed)...
        let handle = element("handle-ruuvi")
        XCTAssertTrue(handle.waitForExistence(timeout: 5), "catalog item should have a handle")
        // ...but dragging it onto Prisma must not move it there.
        handle.press(forDuration: 1.0, thenDragTo: element("store-maito"))

        XCTAssertTrue(element("store-ruuvi").label.contains("K-Rauta"),
                      "catalog item must stay in its own store (got: \(element("store-ruuvi").label))")
    }

    /// Regression: scrubbing a catalog item's quantity high used to hang the
    /// app (row-frame updates re-rendered the view in a loop). It must stay
    /// responsive — proven by adding another item afterwards.
    func testQuantityScrubStaysResponsive() throws {
        launch(seed: "ruuvi|K-Rauta|cat")
        let ruuvi = app.staticTexts["ruuvi"]
        XCTAssertTrue(ruuvi.waitForExistence(timeout: 10))

        // Long rightward drag on the row raises the quantity a lot.
        let start = ruuvi.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = ruuvi.coordinate(withNormalizedOffset: CGVector(dx: 6.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)

        addFreeItem("maito")
        XCTAssertTrue(app.staticTexts["maito"].waitForExistence(timeout: 8),
                      "app hung after quantity scrub")
    }

    /// Regression: the app must stay responsive after a drag-drop — add an
    /// item once the drop settles and confirm it appears.
    func testResponsiveAfterDrop() throws {
        launch(seed: "maito|Prisma;leipä|K-Market")
        addFreeItem("sokeri")

        let handle = element("handle-sokeri")
        XCTAssertTrue(handle.waitForExistence(timeout: 10))
        handle.press(forDuration: 1.0, thenDragTo: element("store-maito"))
        XCTAssertTrue(element("store-sokeri").waitForExistence(timeout: 5), "drop failed")

        addFreeItem("kahvi")
        XCTAssertTrue(app.staticTexts["kahvi"].waitForExistence(timeout: 8),
                      "app hung after drop")
    }
}
