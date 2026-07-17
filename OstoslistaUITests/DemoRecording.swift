import XCTest

/// A scripted walkthrough for recording an App Preview video / screenshots on
/// the Simulator. Runs against the clean "-Screenshots" demo state and performs
/// a natural sequence (store search with prices, check off, drag between stores)
/// with pauses so an external screen recording looks smooth. Not a pass/fail
/// test — it only drives the UI and never asserts.
final class DemoRecording: XCTestCase {
    private var app: XCUIApplication!

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testDemoWalkthrough() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-Screenshots"]
        app.launchEnvironment["UITEST_ITEMS"] =
            "maito 1,5%|Prisma|cat|1,45;kahvi Presidentti|Prisma|cat|5,95;ruisleipä 500g|Prisma;banaani|Prisma;jauheliha 400g|K-Citymarket|cat|3,89;paristot AA|Gigantti|cat|9,90;wc-paperi 12 rl||;omenat 1 kg||"
        app.launch()
        sleep(6)   // hold the grouped list — a long, clean opening for trimming

        // 1) Store product search with live prices (S-kaupat / Prisma).
        let storefront = app.buttons["Hae kaupasta"]
        if storefront.waitForExistence(timeout: 5) { storefront.tap() }
        sleep(1)
        let picker = element("store-picker")
        if picker.waitForExistence(timeout: 5) { picker.tap() }
        sleep(1)
        let prisma = app.buttons["Prisma"].firstMatch
        if prisma.waitForExistence(timeout: 5) { prisma.tap() }
        sleep(1)
        let searchField = app.textFields["Hae kaupasta…"]   // appears only once a store is picked
        if searchField.waitForExistence(timeout: 5) {
            searchField.tap()
            searchField.typeText("maito")
        }
        sleep(5)   // results with prices appear
        let done = app.buttons["Valmis"]
        if done.waitForExistence(timeout: 3) { done.tap() }
        sleep(2)   // back to the list

        // 2) Check off an item — green ✓, strikethrough, drops to the bottom.
        let banaani = app.staticTexts["banaani"].firstMatch
        if banaani.waitForExistence(timeout: 5) { banaani.tap() }
        sleep(2)

        // 3) Drag a free item from "Muut" into the Prisma section.
        let handle = element("handle-omenat 1 kg")
        let target = element("store-maito 1,5%")
        if handle.waitForExistence(timeout: 5), target.exists {
            handle.press(forDuration: 1.0, thenDragTo: target)
        }
        sleep(3)
    }
}
