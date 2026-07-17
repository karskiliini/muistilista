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

    /// Catalog (store-bound) items must not be draggable between stores — they
    /// have no drag handle at all.
    func testCatalogItemHasNoDragHandle() throws {
        launch(seed: "juusto|Prisma|cat;maito|Prisma")

        // Both items are in the Prisma section...
        XCTAssertTrue(element("store-juusto").waitForExistence(timeout: 5), "juusto not shown")
        // ...but only the free-text one has a handle.
        XCTAssertTrue(element("handle-maito").exists, "free item should have a handle")
        XCTAssertFalse(element("handle-juusto").exists,
                       "catalog item must not have a drag handle")
    }
}
