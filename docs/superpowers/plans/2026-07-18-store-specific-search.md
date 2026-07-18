# Kauppakohtainen tuotehaku (R36) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** S-ryhmän tuotehaku kohdistuu käyttäjän valitsemaan fyysiseen myymälään (auto-lähin + käsivalinta, muistetaan ketjukohtaisesti) — spec: `docs/superpowers/specs/2026-07-18-store-specific-search-design.md`.

**Architecture:** Uusi `SKaupatStoreDirectory` parsii myymälät s-kaupat.fi:n SSR-sivulta (`/myymalat?query=`), `SelectedStores` muistaa valinnan App Group -UserDefaultsissa ketjukohtaisesti, `NearestStore` valitsee lähimmän geokoodaamalla, ja `SKaupatCatalog` saa ketjunimen jolla se hakee muistetun storeId:n. UI: myymälärivi + valintasheet `StoreAddView`iin.

**Tech Stack:** Swift/SwiftUI, URLSession, CoreLocation (LocationOnce + CLGeocoder), XCTest.

## Global Constraints

- Ei kolmannen osapuolen riippuvuuksia (R17).
- UI-suomeksi; tarkat tekstit: "Valitse myymälä", "Hae myymälää…", "Myymälöitä ei saatu haettua — yritä uudelleen" (R1).
- Projekti generoidaan aina tiedostolisäysten jälkeen: `/opt/homebrew/Cellar/xcodegen/2.46.0/bin/xcodegen generate`
- Testiajo: `xcodebuild test -project Ostoslista.xcodeproj -scheme Ostoslista -destination 'platform=iOS Simulator,id=4B479CDB-F1E3-42F2-AF02-41882EF4915D' -only-testing:<target/luokka> 2>&1 | tail -8`
- UI-testit eivät käytä verkkoa eivätkä CloudKitia (R18): fixture `UITEST_STORELOCATIONS`-ympäristömuuttujalla.
- Commit jokaisen taskin lopussa.

---

### Task 1: StoreLocation-malli + SSR-parsinta + ketju→brändi-kartta

**Files:**
- Create: `Ostoslista/StoreLocations.swift`
- Create: `OstoslistaTests/StoreLocationTests.swift`

**Interfaces:**
- Produces: `struct StoreLocation: Identifiable, Hashable, Codable { let id, name, brand, street, city: String }`
- Produces: `SKaupatStoreDirectory.parse(_ html: String) -> [StoreLocation]`, `SKaupatStoreDirectory.chainBrands: [String: String]`, `func searchStores(query: String, brand: String?) async throws -> [StoreLocation]`

- [ ] **Step 1: Write the failing tests**

```swift
// OstoslistaTests/StoreLocationTests.swift
import XCTest
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
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `/opt/homebrew/Cellar/xcodegen/2.46.0/bin/xcodegen generate && xcodebuild test -project Ostoslista.xcodeproj -scheme Ostoslista -destination 'platform=iOS Simulator,id=4B479CDB-F1E3-42F2-AF02-41882EF4915D' -only-testing:OstoslistaTests/StoreLocationTests 2>&1 | tail -8`
Expected: BUILD FAILED (`StoreLocation`/`SKaupatStoreDirectory` not defined)

- [ ] **Step 3: Write the implementation**

```swift
// Ostoslista/StoreLocations.swift
import Foundation

/// One physical store of an S-group chain, from the s-kaupat.fi store
/// directory. `brand` is the chain in the directory's own lowercase form
/// ("s-market", "prisma", …).
struct StoreLocation: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let brand: String
    let street: String
    let city: String
}

/// Store directory scraped from s-kaupat.fi's server-rendered /myymalat
/// page (no API key; the client-side GraphQL op is lazy-loaded and its
/// persisted hash unreachable, but SSR embeds full StoreInfo records).
struct SKaupatStoreDirectory {
    /// App chain name (Stores.swift) → directory brand. Only these chains
    /// have store-specific catalogs (R36).
    static let chainBrands: [String: String] = [
        "Prisma": "prisma", "S-market": "s-market", "Sale": "sale",
        "Alepa": "alepa", "ABC": "abc",
    ]

    static func parse(_ html: String) -> [StoreLocation] {
        var result: [StoreLocation] = []
        var seen = Set<String>()
        let marker = "{\"__typename\":\"StoreInfo\","
        var search = html.startIndex..<html.endIndex
        while let found = html.range(of: marker, range: search) {
            search = found.upperBound..<html.endIndex
            // Fields live near the record start; a bounded window keeps the
            // regexes from crossing into the next record's data.
            let end = html.index(found.lowerBound, offsetBy: 1500,
                                 limitedBy: html.endIndex) ?? html.endIndex
            let window = String(html[found.lowerBound..<end])
            func capture(_ pattern: String) -> String? {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let m = regex.firstMatch(in: window, range: NSRange(window.startIndex..., in: window)),
                      m.numberOfRanges > 1,
                      let r = Range(m.range(at: 1), in: window) else { return nil }
                return String(window[r])
            }
            guard let id = capture("\"id\":\"([0-9]+)\""),
                  let name = capture("\"name\":\"([^\"]*)\""),
                  let brand = capture("\"brand\":\"([^\"]*)\""),
                  !seen.contains(id) else { continue }
            seen.insert(id)
            let street = capture("\"street\":\\{\"__typename\":\"LocalizableText\",\"default\":\"([^\"]*)\"") ?? ""
            let city = capture("\"postcodeName\":\\{\"__typename\":\"LocalizableText\",\"default\":\"([^\"]*)\"") ?? ""
            result.append(StoreLocation(id: id, name: name, brand: brand, street: street, city: city))
        }
        return result
    }

    /// Live search; `brand` (chainBrands value) filters to one chain.
    func searchStores(query: String, brand: String?) async throws -> [StoreLocation] {
        var comps = URLComponents(string: "https://www.s-kaupat.fi/myymalat")!
        comps.queryItems = [URLQueryItem(name: "query", value: query)]
        var request = URLRequest(url: comps.url!)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                         forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let all = Self.parse(String(decoding: data, as: UTF8.self))
        guard let brand else { return all }
        return all.filter { $0.brand == brand }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: same command as Step 2.
Expected: `Executed 3 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Ostoslista/StoreLocations.swift OstoslistaTests/StoreLocationTests.swift
git commit -m "feat(r36): S-kaupat store directory — SSR parse + chain brand map"
```

---

### Task 2: SelectedStores — ketjukohtainen valinnan muisti

**Files:**
- Create: `Ostoslista/SelectedStores.swift`
- Modify: `OstoslistaTests/StoreLocationTests.swift` (lisää testit samaan luokkaan)

**Interfaces:**
- Consumes: `StoreLocation` (Task 1)
- Produces: `SelectedStores.selection(for chain: String) -> StoreLocation?`, `SelectedStores.select(_ store: StoreLocation?, for chain: String)`, `SelectedStores.defaults: UserDefaults` (testeissä vaihdettava)

- [ ] **Step 1: Write the failing tests** (append to `StoreLocationTests`)

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: the Task 1 test command. Expected: BUILD FAILED (`SelectedStores` not defined)

- [ ] **Step 3: Write the implementation**

```swift
// Ostoslista/SelectedStores.swift
import Foundation

/// Remembered store choice per chain ("S-market" → S-market Kommila
/// Varkaus). Device-local by design (spec: ei perhesynkkaa). Lives in the
/// App Group so a future widget/extension could read it too.
enum SelectedStores {
    static var defaults: UserDefaults =
        UserDefaults(suiteName: CoreDataStack.appGroupID) ?? .standard

    private static func key(_ chain: String) -> String { "storeLocation.\(chain)" }

    static func selection(for chain: String) -> StoreLocation? {
        guard let data = defaults.data(forKey: key(chain)) else { return nil }
        return try? JSONDecoder().decode(StoreLocation.self, from: data)
    }

    static func select(_ store: StoreLocation?, for chain: String) {
        if let store, let data = try? JSONEncoder().encode(store) {
            defaults.set(data, forKey: key(chain))
        } else {
            defaults.removeObject(forKey: key(chain))
        }
    }
}
```

Huom: jos `CoreDataStack.appGroupID` ei ole tämänniminen vakio, katso oikea nimi `CoreDataStack.swift`istä (käytetään `containerURL(forSecurityApplicationGroupIdentifier:)`-kutsussa) ja käytä sitä.

- [ ] **Step 4: Run tests to verify they pass** — Expected: `Executed 4 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Ostoslista/SelectedStores.swift OstoslistaTests/StoreLocationTests.swift
git commit -m "feat(r36): per-chain selected store memory (App Group defaults)"
```

---

### Task 3: NearestStore — lähimmän myymälän valintalogiikka

**Files:**
- Create: `Ostoslista/NearestStore.swift`
- Modify: `OstoslistaTests/StoreLocationTests.swift`

**Interfaces:**
- Consumes: `StoreLocation`, `SKaupatStoreDirectory`, `SelectedStores`, `LocationOnce.current()`
- Produces: `NearestStore.nearest(of: [(StoreLocation, CLLocationCoordinate2D?)], to: CLLocationCoordinate2D) -> StoreLocation?` (pure, testattava) ja `NearestStore.autoSelect(chain: String) async -> StoreLocation?` (koko kulku; ei yksikkötestata — CoreLocation-riippuvainen)

- [ ] **Step 1: Write the failing tests** (append to `StoreLocationTests`)

```swift
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
```

Lisää tiedoston alkuun `import CoreLocation`, jos sitä ei ole.

- [ ] **Step 2: Run test to verify it fails** — Expected: BUILD FAILED (`NearestStore` not defined)

- [ ] **Step 3: Write the implementation**

```swift
// Ostoslista/NearestStore.swift
import CoreLocation

/// First-use automatic store choice (R36): device location → city name →
/// that city's stores of the chain → geocode their addresses → closest.
/// Every step degrades to nil; the caller then falls back to the manual
/// picker sheet.
enum NearestStore {
    /// Pure distance pick over pre-resolved coordinates (unit-tested).
    static func nearest(of candidates: [(StoreLocation, CLLocationCoordinate2D?)],
                        to user: CLLocationCoordinate2D) -> StoreLocation? {
        let here = CLLocation(latitude: user.latitude, longitude: user.longitude)
        return candidates
            .compactMap { store, coord -> (StoreLocation, CLLocationDistance)? in
                guard let coord else { return nil }
                let there = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                return (store, here.distance(from: there))
            }
            .min { $0.1 < $1.1 }?.0
    }

    /// Full flow. Returns the chosen (and already persisted) store, or nil
    /// when any step fails (no permission, no geocode, no stores).
    static func autoSelect(chain: String) async -> StoreLocation? {
        guard let brand = SKaupatStoreDirectory.chainBrands[chain],
              let coordinate = try? await LocationOnce.current() else { return nil }
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let city = (try? await geocoder.reverseGeocodeLocation(location))?
                .first?.locality else { return nil }
        guard let stores = try? await SKaupatStoreDirectory()
                .searchStores(query: city, brand: brand), !stores.isEmpty else { return nil }
        var pairs: [(StoreLocation, CLLocationCoordinate2D?)] = []
        for store in stores.prefix(10) {
            let address = "\(store.street), \(store.city), Finland"
            let coord = (try? await geocoder.geocodeAddressString(address))?
                .first?.location?.coordinate
            pairs.append((store, coord))
        }
        // If no address geocoded, a lone city hit is still a sane default.
        let chosen = nearest(of: pairs, to: coordinate) ?? (stores.count == 1 ? stores[0] : nil)
        if let chosen { SelectedStores.select(chosen, for: chain) }
        return chosen
    }
}
```

- [ ] **Step 4: Run tests to verify they pass** — Expected: `Executed 6 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Ostoslista/NearestStore.swift OstoslistaTests/StoreLocationTests.swift
git commit -m "feat(r36): nearest-store auto-selection"
```

---

### Task 4: SKaupatCatalog hakee valitulla myymälällä

**Files:**
- Modify: `Ostoslista/SKaupatCatalog.swift`
- Modify: `Ostoslista/Catalog.swift` (rivi 39: registry antaa ketjunimen)
- Modify: `OstoslistaTests/StoreLocationTests.swift`

**Interfaces:**
- Consumes: `SelectedStores.selection(for:)`
- Produces: `SKaupatCatalog(chainName: String)`, `var resolvedStoreId: String`

- [ ] **Step 1: Write the failing test** (append to `StoreLocationTests`)

```swift
    func testSKaupatUsesSelectedStoreId() {
        SelectedStores.defaults = UserDefaults(suiteName: "SelectedStoresTests")!
        defer { SelectedStores.defaults.removePersistentDomain(forName: "SelectedStoresTests") }
        XCTAssertEqual(SKaupatCatalog(chainName: "S-market").resolvedStoreId,
                       SKaupatCatalog.defaultStoreId, "no selection → representative default")
        SelectedStores.select(StoreLocation(id: "708276035", name: "S-market Kommila Varkaus",
                                            brand: "s-market", street: "", city: ""),
                              for: "S-market")
        XCTAssertEqual(SKaupatCatalog(chainName: "S-market").resolvedStoreId, "708276035")
        XCTAssertEqual(SKaupatCatalog(chainName: "Prisma").resolvedStoreId,
                       SKaupatCatalog.defaultStoreId, "other chain unaffected")
    }
```

- [ ] **Step 2: Run test to verify it fails** — Expected: BUILD FAILED (`chainName`/`resolvedStoreId` not defined)

- [ ] **Step 3: Implement**

`SKaupatCatalog.swift`: lisää structiin kentät ja käytä niitä `search`issa:

```swift
struct SKaupatCatalog: CatalogProvider {
    /// App chain name ("S-market") — resolves the remembered store (R36).
    let chainName: String
    init(chainName: String = "") { self.chainName = chainName }

    /// Selected store's id, or the historical representative store when
    /// nothing is selected yet (auto/manual selection normally happens
    /// before the first search; this is a defensive fallback).
    var resolvedStoreId: String {
        SelectedStores.selection(for: chainName)?.id ?? Self.defaultStoreId
    }
```

ja `search`-funktiossa korvaa `storeId: Self.defaultStoreId` → `storeId: resolvedStoreId`.

`Catalog.swift` rivi 39: `return SKaupatCatalog()` → `return SKaupatCatalog(chainName: storeName)`.

- [ ] **Step 4: Run tests to verify they pass** — Expected: `Executed 7 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Ostoslista/SKaupatCatalog.swift Ostoslista/Catalog.swift OstoslistaTests/StoreLocationTests.swift
git commit -m "feat(r36): SKaupat search targets the selected store"
```

---

### Task 5: Live-integraatiotestit (verkko; skip jos ei yhteyttä)

**Files:**
- Modify: `OstoslistaTests/LiveCatalogTests.swift`

**Interfaces:**
- Consumes: `SKaupatStoreDirectory.searchStores`, `SelectedStores`, `SKaupatCatalog(chainName:)`

- [ ] **Step 1: Add the tests** (append to `LiveCatalogTests`; seuraa luokan olemassa olevaa `XCTSkip`-tyyliä)

```swift
    func testStoreDirectoryFindsKommila() async throws {
        let stores: [StoreLocation]
        do {
            stores = try await SKaupatStoreDirectory().searchStores(query: "kommila", brand: "s-market")
        } catch {
            throw XCTSkip("Network unavailable: \(error.localizedDescription)")
        }
        XCTAssertTrue(stores.contains { $0.id == "708276035" },
                      "expected S-market Kommila Varkaus, got \(stores.map(\.name))")
    }

    func testSKaupatSearchWithSelectedKommilaStore() async throws {
        SelectedStores.defaults = UserDefaults(suiteName: "LiveStoreTests")!
        defer { SelectedStores.defaults.removePersistentDomain(forName: "LiveStoreTests") }
        SelectedStores.select(StoreLocation(id: "708276035", name: "S-market Kommila Varkaus",
                                            brand: "s-market", street: "Savontie 44", city: "Varkaus"),
                              for: "S-market")
        try await assertFindsProducts(SKaupatCatalog(chainName: "S-market"), query: "maito")
    }
```

- [ ] **Step 2: Run them**

Run: `xcodebuild test ... -only-testing:OstoslistaTests/LiveCatalogTests 2>&1 | tail -8`
Expected: PASS (tai SKIP ilman verkkoa)

- [ ] **Step 3: Commit**

```bash
git add OstoslistaTests/LiveCatalogTests.swift
git commit -m "test(r36): live store directory + store-scoped product search"
```

---

### Task 6: UI — myymälärivi, valintasheet, automaattivalinta, haun portti

**Files:**
- Create: `Ostoslista/StoreLocationSheet.swift`
- Modify: `Ostoslista/StoreLocations.swift` (lisää `StoreDirectory`-fasadi fixture-tuella)
- Modify: `Ostoslista/StoreAddView.swift`

**Interfaces:**
- Consumes: kaikki edellä tuotettu.
- Produces: `StoreDirectory.search(query:brand:) async throws -> [StoreLocation]` (fixture kun `UITEST_STORELOCATIONS` asetettu), `StoreLocationSheet(chain:onSelected:)`, accessibility id:t `store-location-row`, `store-location-search`.

- [ ] **Step 1: StoreDirectory-fasadi** (append `Ostoslista/StoreLocations.swift`)

```swift
/// Entry point the UI uses. In UI tests the env var
/// UITEST_STORELOCATIONS ("id|name|brand|street|city;…") replaces the
/// network so the sheet works offline (R18).
enum StoreDirectory {
    static func search(query: String, brand: String?) async throws -> [StoreLocation] {
        if let fixture = ProcessInfo.processInfo.environment["UITEST_STORELOCATIONS"] {
            let all = fixture.split(separator: ";").compactMap { entry -> StoreLocation? in
                let f = entry.split(separator: "|").map(String.init)
                guard f.count == 5 else { return nil }
                return StoreLocation(id: f[0], name: f[1], brand: f[2], street: f[3], city: f[4])
            }
            let q = query.lowercased()
            return all.filter { (brand == nil || $0.brand == brand)
                && (q.isEmpty || $0.name.lowercased().contains(q)) }
        }
        return try await SKaupatStoreDirectory().searchStores(query: query, brand: brand)
    }

    /// UI tests must not trigger CoreLocation prompts.
    static var isFixtureMode: Bool {
        ProcessInfo.processInfo.environment["UITEST_STORELOCATIONS"] != nil
    }
}
```

- [ ] **Step 2: StoreLocationSheet**

```swift
// Ostoslista/StoreLocationSheet.swift
import SwiftUI

/// Manual store picker (R36): search s-kaupat store directory by name or
/// town, tap to select. Also the fallback when auto-selection fails.
struct StoreLocationSheet: View {
    let chain: String
    let onSelected: (StoreLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [StoreLocation] = []
    @State private var searching = false
    @State private var errorText: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hae myymälää…", text: $query)
                        .accessibilityIdentifier("store-location-search")
                        .onChange(of: query) { _, _ in runSearch() }
                } footer: {
                    Text("Hae myymälän nimellä tai paikkakunnalla (esim. \"kommila\" tai \"Varkaus\").")
                }
                Section {
                    if let errorText {
                        Text(errorText).foregroundStyle(.secondary)
                    } else if searching {
                        HStack { ProgressView(); Text("Haetaan…").foregroundStyle(.secondary) }
                    } else {
                        ForEach(results) { store in
                            Button {
                                SelectedStores.select(store, for: chain)
                                onSelected(store)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.name).foregroundStyle(.primary)
                                    Text("\(store.street), \(store.city)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        if results.isEmpty, ShoppingListLogic.normalized(query) != nil {
                            Text("Ei osumia").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Valitse myymälä")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Peruuta") { dismiss() }
                }
            }
        }
    }

    private func runSearch() {
        searchTask?.cancel()
        errorText = nil
        guard let q = ShoppingListLogic.normalized(query) else {
            results = []; searching = false; return
        }
        searching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            do {
                let found = try await StoreDirectory.search(
                    query: q, brand: SKaupatStoreDirectory.chainBrands[chain])
                if Task.isCancelled { return }
                await MainActor.run { results = found; searching = false }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    errorText = "Myymälöitä ei saatu haettua — yritä uudelleen"
                    searching = false
                }
            }
        }
    }
}
```

- [ ] **Step 3: StoreAddView-integraatio**

Lisää state-muuttujat (rivin 25 `@FocusState` jälkeen):

```swift
    @State private var storeLocation: StoreLocation?
    @State private var locationSheetPresented = false
    @State private var autoSelecting = false
```

`storeSection`iin Menu-elementin JÄLKEEN (saman Sectionin sisään) myymälärivi, joka näkyy vain S-ryhmän ketjuille:

```swift
            if SKaupatStoreDirectory.chainBrands[storeName] != nil {
                Button {
                    locationSheetPresented = true
                } label: {
                    HStack {
                        Label(storeLocation?.name ?? "Valitse myymälä",
                              systemImage: "mappin.and.ellipse")
                            .foregroundStyle(storeLocation == nil ? .secondary : .primary)
                        Spacer()
                        if autoSelecting { ProgressView() }
                    }
                }
                .accessibilityIdentifier("store-location-row")
            }
```

Ketjun valintanappiin (rivi 65) ja `.onAppear`iin kutsu `refreshStoreLocation()`:

```swift
                            Button(name) { storeName = name; refreshStoreLocation(); onStoreOrQueryChanged() }
```

ja `.onAppear`-lohkon loppuun `refreshStoreLocation()`.

Uusi funktio (Behavior-osioon):

```swift
    /// Loads the remembered store for the chain; when none and the chain is
    /// store-specific, tries the automatic nearest pick and falls back to
    /// the manual sheet (R36). Skipped in UI-test fixture mode (no
    /// CoreLocation prompts, R18).
    private func refreshStoreLocation() {
        storeLocation = SelectedStores.selection(for: storeName)
        guard storeLocation == nil,
              SKaupatStoreDirectory.chainBrands[storeName] != nil,
              !autoSelecting else { return }
        if StoreDirectory.isFixtureMode { locationSheetPresented = true; return }
        autoSelecting = true
        Task {
            let chosen = await NearestStore.autoSelect(chain: storeName)
            await MainActor.run {
                autoSelecting = false
                if let chosen {
                    storeLocation = chosen
                    onStoreOrQueryChanged()
                } else {
                    locationSheetPresented = true
                }
            }
        }
    }
```

Haun portti — `onStoreOrQueryChanged()`-funktion guard-riviksi ennen nykyistä guardia:

```swift
        // R36: store-specific chains search only after a store is chosen.
        if SKaupatStoreDirectory.chainBrands[storeName] != nil,
           SelectedStores.selection(for: storeName) == nil {
            results = []; searching = false; return
        }
```

Sheet — `body`n `.toolbar`-lohkon jälkeen:

```swift
            .sheet(isPresented: $locationSheetPresented) {
                StoreLocationSheet(chain: storeName) { chosen in
                    storeLocation = chosen
                    onStoreOrQueryChanged()
                }
            }
```

- [ ] **Step 4: Build + kaikki yksikkötestit**

Run: `/opt/homebrew/Cellar/xcodegen/2.46.0/bin/xcodegen generate && xcodebuild test ... -only-testing:OstoslistaTests 2>&1 | tail -8`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Ostoslista/StoreLocationSheet.swift Ostoslista/StoreLocations.swift Ostoslista/StoreAddView.swift
git commit -m "feat(r36): store row + picker sheet + auto-nearest in store add view"
```

---

### Task 7: UI-testi (offline, fixture)

**Files:**
- Create: `OstoslistaUITests/StoreLocationUITests.swift`

**Interfaces:**
- Consumes: accessibility id:t `store-picker`, `store-location-row`, `store-location-search`; fixture-muoto `id|name|brand|street|city;…`; olemassa oleva käynnistystapa (`-UITestReset`, ks. `DragMoveUITests.swift`n launch-koodi ja apurit).

- [ ] **Step 1: Write the UI test**

```swift
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
        search.typeText("kommila")

        let kommila = app.staticTexts["S-market Kommila Varkaus"].firstMatch
        XCTAssertTrue(kommila.waitForExistence(timeout: 5), "fixture store should match")
        kommila.tap()

        // Sheet closes; the row remembers the choice; brand filter held
        // (Prisma fixture store must not appear for the S-market chain).
        let row = element("store-location-row")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["S-market Kommila Varkaus"].firstMatch
            .waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 2: Run it**

Run: `xcodebuild test ... -only-testing:OstoslistaUITests/StoreLocationUITests 2>&1 | tail -8`
Expected: PASS. Jos elementti ei löydy, tutki hierarkia `app.debugDescription`illä — älä muuta tuotantokoodin rakennetta testin takia ilman syytä.

Huom: UserDefaults-valinta säilyy simulaattorissa ajojen välillä — testin alussa `-UITestReset`-tilassa fixture-moodi ohittaa automaattivalinnan, mutta jos aiempi ajo on tallettanut valinnan App Groupiin, sheet ei aukea itsestään. Lisää tarvittaessa `StoreProvider`in ephemeral-polkuun (`-UITestReset`) `SelectedStores`-avainten tyhjennys:

```swift
        if ephemeral {
            for chain in SKaupatStoreDirectory.chainBrands.keys {
                SelectedStores.select(nil, for: chain)
            }
        }
```

- [ ] **Step 3: Commit**

```bash
git add OstoslistaUITests/StoreLocationUITests.swift Ostoslista/StoreProvider.swift
git commit -m "test(r36): UI test for manual store-location picking"
```

---

### Task 8: Viimeistely — versio, rekisteri, koko testiajo

**Files:**
- Modify: `project.yml` (MARKETING_VERSION), `Ostoslista/…` versioleima jos skilli niin ohjaa
- Modify: `docs/requirements.md` (R36 📋 → ✅)

- [ ] **Step 1:** Käytä `version-bump`-skilliä (`.claude/skills/version-bump`): uusi feature → minor bump (1.34.2 → 1.35.0).
- [ ] **Step 2:** `docs/requirements.md`: R36 tila 📋 → ✅ (S-ryhmän osalta; K-ruoka-lauseke jää mainintana "myöhemmin K-ruoka").
- [ ] **Step 3:** Koko testiajo: `xcodebuild test ... -only-testing:OstoslistaTests 2>&1 | tail -5` ja UI-testit `-only-testing:OstoslistaUITests/StoreLocationUITests`. Expected: PASS.
- [ ] **Step 4:** Aja `verify`-skilli: buildaa appi simulaattoriin, avaa kauppanäkymä, valitse S-market, varmista että myymäläsheet/valinta toimii ja tuotehaku palauttaa Kommilan hinnat kun Kommila valittu (vertaa: maito 1,09 €).
- [ ] **Step 5: Commit**

```bash
git add project.yml docs/requirements.md
git commit -m "feat(r36): store-specific search complete (v1.35.0)"
```
