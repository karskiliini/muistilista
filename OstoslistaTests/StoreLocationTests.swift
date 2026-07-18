// OstoslistaTests/StoreLocationTests.swift
import XCTest
import CoreLocation
@testable import Ostoslista

final class StoreLocationTests: XCTestCase {

    /// Real record shape captured from s-kaupat.fi/myymalat SSR output 2026-07-18.
    private let fixture = """
    junk{"__typename":"StoreInfo","id":"708276035","slug":"s-market-kommila-varkaus",\
    "name":"S-market Kommila Varkaus","brand":"s-market","domains":["S_KAUPAT"],\
    "location":{"__typename":"StoreLocation","address":{"__typename":"StoreAddress",\
    "street":{"__typename":"LocalizableText","default":"Savontie 44"},"postcode":"78300",\
    "postcodeName":{"__typename":"LocalizableText","default":"Varkaus"}}},"weeklyOpeningHours":[]}\
    more junk{"__typename":"StoreInfo","id":"513971200","slug":"prisma-mikkeli",\
    "name":"Prisma Mikkeli","brand":"prisma","domains":["S_KAUPAT"],\
    "location":{"__typename":"StoreLocation","address":{"__typename":"StoreAddress",\
    "street":{"__typename":"LocalizableText","default":"Maaherrankatu 13"},"postcode":"50100",\
    "postcodeName":{"__typename":"LocalizableText","default":"Mikkeli"}}},"weeklyOpeningHours":[]}\
    {"__typename":"StoreInfo","id":"708276035","slug":"s-market-kommila-varkaus",\
    "name":"S-market Kommila Varkaus","brand":"s-market","domains":[]}
    """

    func testParseExtractsStores() {
        let stores = SKaupatStoreDirectory.parse(fixture)
        XCTAssertEqual(stores.count, 2, "duplicate id must be dropped")
        let kommila = stores.first { $0.id == "708276035" }
        XCTAssertEqual(kommila?.name, "S-market Kommila Varkaus")
        XCTAssertEqual(kommila?.brand, "s-market")
        XCTAssertEqual(kommila?.street, "Savontie 44")
        XCTAssertEqual(kommila?.city, "Varkaus")
    }

    func testParseToleratesMissingAddress() {
        let broken = "{\"__typename\":\"StoreInfo\",\"id\":\"1\",\"name\":\"X\",\"brand\":\"sale\"}"
        let stores = SKaupatStoreDirectory.parse(broken)
        XCTAssertEqual(stores.first?.street, "")
        XCTAssertEqual(stores.first?.city, "")
    }

    func testChainBrands() {
        XCTAssertEqual(SKaupatStoreDirectory.chainBrands["S-market"], "s-market")
        XCTAssertEqual(SKaupatStoreDirectory.chainBrands["Prisma"], "prisma")
        XCTAssertNil(SKaupatStoreDirectory.chainBrands["Tokmanni"])
    }

    func testSelectedStoreRoundTrip() {
        SelectedStores.defaults = UserDefaults(suiteName: "SelectedStoresTests")!
        defer { SelectedStores.defaults.removePersistentDomain(forName: "SelectedStoresTests") }
        XCTAssertNil(SelectedStores.selection(for: "S-market"))
        let kommila = StoreLocation(id: "708276035", name: "S-market Kommila Varkaus",
                                    brand: "s-market", street: "Savontie 44", city: "Varkaus")
        SelectedStores.select(kommila, for: "S-market")
        XCTAssertEqual(SelectedStores.selection(for: "S-market"), kommila)
        XCTAssertNil(SelectedStores.selection(for: "Prisma"), "selection is per chain")
        SelectedStores.select(nil, for: "S-market")
        XCTAssertNil(SelectedStores.selection(for: "S-market"))
    }

    func testNearestPicksClosestAndSkipsUngeocodable() {
        let a = StoreLocation(id: "1", name: "A", brand: "s-market", street: "x", city: "y")
        let b = StoreLocation(id: "2", name: "B", brand: "s-market", street: "x", city: "y")
        let c = StoreLocation(id: "3", name: "C", brand: "s-market", street: "x", city: "y")
        let user = CLLocationCoordinate2D(latitude: 62.31, longitude: 27.88)  // Varkaus
        let picked = NearestStore.nearest(of: [
            (a, CLLocationCoordinate2D(latitude: 60.17, longitude: 24.94)),   // Helsinki ~300 km
            (b, CLLocationCoordinate2D(latitude: 62.32, longitude: 27.90)),   // ~1 km
            (c, nil),                                                          // geocode failed
        ], to: user)
        XCTAssertEqual(picked?.id, "2")
    }

    func testNearestReturnsNilWhenNothingGeocoded() {
        let a = StoreLocation(id: "1", name: "A", brand: "sale", street: "x", city: "y")
        XCTAssertNil(NearestStore.nearest(of: [(a, nil)],
                                          to: CLLocationCoordinate2D(latitude: 0, longitude: 0)))
    }
}
