import XCTest

/// Verifies the store drag-and-drop the user kept reporting as broken:
/// grabbing a free item's drag handle and sliding it onto another store's
/// group must move the item into that store. Instead of shipping and asking
/// the user to test on-device, this fakes the press-then-slide gesture in the
/// Simulator so the behaviour is proven here.
final class DragMoveUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestReset"]
        app.launch()
    }

    /// Any element with the given identifier, regardless of its type — the
    /// drag handle is an Image, the subtitle a static text, so a type-agnostic
    /// lookup keeps the test resilient to how SwiftUI exposes each one.
    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func addFreeItem(_ name: String) {
        let field = app.textFields["Lisää tuote…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Add field missing")
        field.tap()
        field.typeText("\(name)\n")
    }

    /// Assign an item to a store through the ⋯ actions menu, so a store
    /// section exists to drop onto.
    private func moveToStoreViaMenu(item: String, store: String) {
        element("actions-\(item)").tap()
        app.buttons["Siirrä kauppaan"].tap()
        app.buttons[store].tap()
    }

    func testDragFreeItemOntoStoreGroupMovesIt() throws {
        addFreeItem("maito")
        addFreeItem("sokeri")

        // Set up a Prisma group by moving "maito" there via the menu.
        moveToStoreViaMenu(item: "maito", store: "Prisma")
        let maitoStore = element("store-maito")
        XCTAssertTrue(maitoStore.waitForExistence(timeout: 5))
        XCTAssertEqual(maitoStore.label, "Prisma", "Setup failed: maito not in Prisma")

        // "sokeri" starts with no store (no subtitle rendered).
        XCTAssertFalse(element("store-sokeri").exists, "sokeri should start store-less")

        // The gesture under test: press the handle, then slide it onto the
        // Prisma row.
        let handle = element("handle-sokeri")
        XCTAssertTrue(handle.waitForExistence(timeout: 5), "sokeri drag handle missing")
        handle.press(forDuration: 1.0, thenDragTo: maitoStore)

        // Diagnostic: dNmM shows how many URIs reached the drop closure (N)
        // and how many items actually moved (M). d0 => drag/drop never landed.
        let debug = element("debug-drop")
        _ = debug.waitForExistence(timeout: 2)
        print("DROP-DEBUG: \(debug.label)")

        // sokeri must now be in Prisma.
        let sokeriStore = element("store-sokeri")
        XCTAssertTrue(sokeriStore.waitForExistence(timeout: 5),
                      "sokeri never gained a store (debug: \(debug.label))")
        XCTAssertEqual(sokeriStore.label, "Prisma", "sokeri did not move to Prisma")
    }
}
