import SwiftUI
import CoreData

/// Optional store-based add flow (R23): pick a store, search the store's
/// live catalog (where available), and tap a hit to add it. The shelf
/// location is never typed — it comes from the store's own data (e.g.
/// K-Rauta) and is shown behind the info view. Free-text add stays for
/// stores without a catalog.
struct StoreAddView: View {
    /// Prefilled from the main screen's add field when the store icon is tapped.
    let initialQuery: String
    /// Called with the new item's ID after adding, so the list can scroll to it.
    let onAdded: (NSManagedObjectID) -> Void

    @EnvironmentObject private var store: StoreProvider
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kRuoka = KRuokaWebEngine.shared

    @AppStorage("lastStoreName") private var storeName = ""
    @State private var productName = ""
    @State private var results: [CatalogProduct] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var productFocused: Bool
    @State private var storeLocation: StoreLocation?
    @State private var locationSheetPresented = false
    @State private var autoSelectingChain: String?

    init(initialQuery: String = "", onAdded: @escaping (NSManagedObjectID) -> Void = { _ in }) {
        self.initialQuery = initialQuery
        self.onAdded = onAdded
    }

    private var catalog: CatalogProvider? { CatalogRegistry.provider(for: storeName) }

    var body: some View {
        NavigationStack {
            Form {
                storeSection
                productSection
                if catalog != nil { catalogResultsSection }
                addSection
            }
            .navigationTitle(storeName.isEmpty ? "Kauppalisäys" : storeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valmis") { dismiss() }
                }
            }
            .onAppear {
                if productName.isEmpty, !initialQuery.isEmpty {
                    productName = initialQuery
                    onStoreOrQueryChanged()
                }
                productFocused = true
                refreshStoreLocation()
            }
            .sheet(isPresented: $locationSheetPresented) {
                StoreLocationSheet(chain: storeName) { chosen in
                    storeLocation = chosen
                    onStoreOrQueryChanged()
                }
            }
        }
    }

    private var storeSection: some View {
        Section("Kauppa") {
            Menu {
                ForEach(Stores.groups) { group in
                    Section(group.name) {
                        ForEach(group.stores, id: \.self) { name in
                            Button(name) { storeName = name; refreshStoreLocation(); onStoreOrQueryChanged() }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(storeName.isEmpty ? "Valitse kauppa" : storeName)
                        .foregroundStyle(storeName.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("store-picker")
            if SKaupatStoreDirectory.chainBrands[storeName] != nil {
                Button {
                    locationSheetPresented = true
                } label: {
                    HStack {
                        Label(storeLocation?.name ?? "Valitse myymälä",
                              systemImage: "mappin.and.ellipse")
                            .foregroundStyle(storeLocation == nil ? .secondary : .primary)
                        Spacer()
                        if autoSelectingChain == storeName { ProgressView() }
                    }
                }
                .accessibilityIdentifier("store-location-row")
            }
        }
    }

    private var productSection: some View {
        Section(catalog != nil ? "Hae tuotetta" : "Tuote") {
            TextField(catalog != nil ? "Hae kaupasta…" : "Tuotteen nimi", text: $productName)
                .focused($productFocused)
                .submitLabel(catalog == nil ? .done : .search)
                .onSubmit { if catalog == nil { addManual() } }
                .onChange(of: productName) { _, _ in onStoreOrQueryChanged() }
        }
    }

    /// K-ruoka runs through the embedded web engine; surface its state.
    private var kRuokaUnavailable: Bool {
        catalog is KRuokaCatalog && kRuoka.status == .unavailable
    }
    private var kRuokaWarming: Bool {
        catalog is KRuokaCatalog && (kRuoka.status == .warming || kRuoka.status == .idle)
    }

    private var catalogResultsSection: some View {
        Section {
            if kRuokaUnavailable {
                Label("K-ruoan tiedot eivät ole juuri nyt saatavilla.", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.secondary)
            } else if kRuokaWarming && ShoppingListLogic.normalized(productName) != nil {
                HStack { ProgressView(); Text("Yhdistetään K-ruokaan…").foregroundStyle(.secondary) }
            } else if searching {
                HStack { ProgressView(); Text("Haetaan…").foregroundStyle(.secondary) }
            } else if !results.isEmpty {
                ForEach(results) { product in
                    NavigationLink {
                        CatalogProductDetailView(product: product, storeName: storeName) { addCatalog(product) }
                    } label: {
                        CatalogRow(product: product)
                    }
                    // Swipe left → add one straight to the list (skip the
                    // product page).
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button { addCatalog(product, quantity: 1) } label: {
                            Label("Lisää", systemImage: "cart.badge.plus")
                        }
                        .tint(.green)
                    }
                    // Swipe right → add several at once.
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button { addCatalog(product, quantity: 2) } label: { Text("2 kpl") }.tint(.blue)
                        Button { addCatalog(product, quantity: 3) } label: { Text("3 kpl") }.tint(.indigo)
                        Button { addCatalog(product, quantity: 6) } label: { Text("6 kpl") }.tint(.purple)
                    }
                }
            } else if ShoppingListLogic.normalized(productName) != nil {
                Text("Ei osumia").foregroundStyle(.secondary)
            }
        } header: {
            Text("Valikoima")
        } footer: {
            Text("Napauta tuote lisätäksesi. Hyllypaikka (jos kauppa tarjoaa sen) näkyy tuotteen ⓘ-näkymässä.")
        }
    }

    private var addSection: some View {
        Section {
            Button(catalog != nil ? "Lisää vapaana tekstinä" : "Lisää listalle") { addManual() }
                .disabled(ShoppingListLogic.normalized(productName) == nil
                          || ShoppingListLogic.normalized(storeName) == nil)
        }
    }

    // MARK: - Behavior

    /// Loads the remembered store for the chain; when none and the chain is
    /// store-specific, tries the automatic nearest pick and falls back to
    /// the manual sheet (R36). Skipped in UI-test fixture mode (no
    /// CoreLocation prompts, R18).
    private func refreshStoreLocation() {
        storeLocation = SelectedStores.selection(for: storeName)
        // A different chain's in-flight auto-select must not block this
        // one — only this chain's own in-flight task is a reason to wait.
        guard storeLocation == nil,
              SKaupatStoreDirectory.chainBrands[storeName] != nil,
              autoSelectingChain != storeName else { return }
        if StoreDirectory.isFixtureMode { locationSheetPresented = true; return }
        let chain = storeName
        autoSelectingChain = chain
        Task {
            _ = await NearestStore.autoSelect(chain: chain)
            await MainActor.run {
                if autoSelectingChain == chain { autoSelectingChain = nil }
                // The user may have switched to another chain while this
                // resolved — a stale completion must not touch its UI.
                guard chain == storeName else { return }
                // Re-read rather than trust the task's return value: a
                // manual pick made meanwhile wins over the auto-selected one.
                storeLocation = SelectedStores.selection(for: chain)
                if storeLocation != nil {
                    onStoreOrQueryChanged()
                } else {
                    locationSheetPresented = true
                }
            }
        }
    }

    /// Debounced catalog search whenever store or query changes.
    private func onStoreOrQueryChanged() {
        searchTask?.cancel()
        // R36: store-specific chains search only after a store is chosen.
        if SKaupatStoreDirectory.chainBrands[storeName] != nil,
           SelectedStores.selection(for: storeName) == nil {
            results = []; searching = false; return
        }
        guard let catalog, let query = ShoppingListLogic.normalized(productName) else {
            results = []; searching = false; return
        }
        searching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            let found = (try? await catalog.search(query)) ?? []
            if Task.isCancelled { return }
            await MainActor.run { results = found; searching = false }
        }
    }

    private func addCatalog(_ product: CatalogProduct, quantity: Int = 1) {
        // Shelf comes from the chain's own data (nil for stores that don't
        // publish it) — never typed by the user.
        insert(name: product.name, shelf: product.shelfLocation, catalog: product, quantity: quantity)
    }

    private func addManual() {
        guard let name = ShoppingListLogic.normalized(productName) else { return }
        insert(name: name, shelf: nil, catalog: nil, quantity: 1)
    }

    /// Shared insert: item lands in the list's store and carries the
    /// catalog's price/description/images/shelf when present. Adding one
    /// item closes the store view and hands the new item's ID back so the
    /// list can scroll to it.
    private func insert(name: String, shelf: String?, catalog: CatalogProduct?, quantity: Int) {
        guard let storeTrimmed = ShoppingListLogic.normalized(storeName) else { return }
        let item = CDShoppingItem(context: context)
        item.name = name
        item.quantity = Int64(max(1, quantity))
        item.storeName = storeTrimmed
        item.shelfLocation = shelf
        item.catalogPrice = catalog?.priceText
        item.priceValue = catalog?.price ?? 0
        item.fromCatalog = catalog != nil
        item.productDescription = catalog?.description
        item.imageURLsString = catalog?.imageURLs.map(\.absoluteString).joined(separator: "\n")
        if let list = store.currentList {
            if let listStore = list.objectID.persistentStore { context.assign(item, to: listStore) }
            item.list = list
        }
        try? context.save()   // makes the objectID permanent
        onAdded(item.objectID)
        dismiss()
    }
}

private struct CatalogRow: View {
    let product: CatalogProduct

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: product.imageURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "photo").foregroundStyle(.quaternary)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(.subheadline)
                if let shelf = product.shelfLocation {
                    Label(shelf, systemImage: "mappin.and.ellipse")
                        .font(.caption2).foregroundStyle(.tint).lineLimit(1)
                } else if let hint = ShoppingListLogic.categoryHint(product.categoryPath) {
                    Text(hint).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let price = product.priceText {
                    Text(price).font(.subheadline.monospacedDigit())
                }
                if let comparison = product.comparison {
                    Text(comparison).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
