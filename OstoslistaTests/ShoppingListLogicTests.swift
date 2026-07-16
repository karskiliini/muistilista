import XCTest
@testable import Ostoslista

final class ShoppingListLogicTests: XCTestCase {
    func testNormalizedTrimsWhitespace() {
        XCTAssertEqual(ShoppingListLogic.normalized("  maito \n"), "maito")
    }

    func testNormalizedRejectsEmptyInput() {
        XCTAssertNil(ShoppingListLogic.normalized(""))
        XCTAssertNil(ShoppingListLogic.normalized("   \n\t"))
    }

    func testSortedPutsUncheckedFirstThenOldestFirst() {
        let bread  = ShoppingItem(name: "leipä", isDone: true,  createdAt: Date(timeIntervalSince1970: 1))
        let milk   = ShoppingItem(name: "maito", isDone: false, createdAt: Date(timeIntervalSince1970: 3))
        let coffee = ShoppingItem(name: "kahvi", isDone: false, createdAt: Date(timeIntervalSince1970: 2))
        let result = ShoppingListLogic.sorted([bread, milk, coffee])
        XCTAssertEqual(result.map(\.name), ["kahvi", "maito", "leipä"])
    }

    func testCheckedReturnsOnlyCheckedItems() {
        let bread = ShoppingItem(name: "leipä", isDone: true)
        let milk  = ShoppingItem(name: "maito", isDone: false)
        XCTAssertEqual(ShoppingListLogic.checked([bread, milk]).map(\.name), ["leipä"])
    }

    func testQuantityStaysAtStartForShortDrag() {
        XCTAssertEqual(ShoppingListLogic.quantity(start: 1, dragWidth: 0), 1)
        XCTAssertEqual(ShoppingListLogic.quantity(start: 1, dragWidth: 35), 1)
    }

    func testQuantityGrowsOneStepPer36Points() {
        XCTAssertEqual(ShoppingListLogic.quantity(start: 1, dragWidth: 36), 2)
        XCTAssertEqual(ShoppingListLogic.quantity(start: 1, dragWidth: 200), 6)
    }

    func testQuantityScrubsDownWhenDraggingLeft() {
        XCTAssertEqual(ShoppingListLogic.quantity(start: 4, dragWidth: -72), 2)
    }

    func testQuantityNeverGoesBelowOne() {
        XCTAssertEqual(ShoppingListLogic.quantity(start: 2, dragWidth: -500), 1)
        XCTAssertEqual(ShoppingListLogic.quantity(start: 1, dragWidth: -36), 1)
    }
}
