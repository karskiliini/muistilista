import XCTest

/// Drives the store drag-and-drop with faked press-then-slide gestures in the
/// Simulator, so its data outcomes are proven here instead of by shipping and
/// asking the user to test on-device. These verify WHERE items land (store and
/// order); the live feel (lift, ghost, rows making room) is a visual matter the
/// user confirms on device.
final class DragMoveUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestReset"]
        app.launch()
    }

    /// Any element with the given identifier, regardless of type — the handle
    /// is an Image, a subtitle a static text; a type-agnostic lookup is robust.
    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func addFreeItem(_ name: String) {
        let field = app.textFields["Lisää tuote…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Add field missing")
        field.tap()
        field.typeText("\(name)\n")
    }

    /// Assign an item to a store through the ⋯ actions menu.
    private func moveToStoreViaMenu(item: String, store: String) {
        element("actions-\(item)").tap()
        app.buttons["Siirrä kauppaan"].tap()
        app.buttons[store].tap()
    }

    /// Dragging a free item onto another store's section moves it there.
    func testDragFreeItemOntoStoreGroupMovesIt() throws {
        addFreeItem("maito")
        addFreeItem("sokeri")

        moveToStoreViaMenu(item: "maito", store: "Prisma")
        let maitoStore = element("store-maito")
        XCTAssertTrue(maitoStore.waitForExistence(timeout: 5))
        XCTAssertEqual(maitoStore.label, "Prisma", "Setup failed: maito not in Prisma")
        XCTAssertFalse(element("store-sokeri").exists, "sokeri should start store-less")

        let handle = element("handle-sokeri")
        XCTAssertTrue(handle.waitForExistence(timeout: 5), "sokeri drag handle missing")
        handle.press(forDuration: 1.0, thenDragTo: maitoStore)

        let sokeriStore = element("store-sokeri")
        XCTAssertTrue(sokeriStore.waitForExistence(timeout: 5),
                      "sokeri never gained a store (debug: \(element("debug-drop").label))")
        XCTAssertEqual(sokeriStore.label, "Prisma", "sokeri did not move to Prisma")
    }

    /// Dragging an item within its own group reorders it rather than moving it
    /// to another store. Dropped at the bottom, it becomes last.
    func testDragReordersWithinGroup() throws {
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

    /// A stored item dragged down to the bottom lands in the "Ei kauppaa" zone
    /// (which is always available during a drag) and loses its store.
    func testDragToNoStoreClearsStore() throws {
        addFreeItem("maito")
        moveToStoreViaMenu(item: "maito", store: "Prisma")
        let maitoStore = element("store-maito")
        XCTAssertTrue(maitoStore.waitForExistence(timeout: 5))
        XCTAssertEqual(maitoStore.label, "Prisma", "Setup failed: maito not in Prisma")

        let handle = element("handle-maito")
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        handle.press(forDuration: 1.0, thenDragTo: element("debug-drop"))

        XCTAssertFalse(element("store-maito").waitForExistence(timeout: 3),
                       "maito should have lost its store (debug: \(element("debug-drop").label))")
    }
}
