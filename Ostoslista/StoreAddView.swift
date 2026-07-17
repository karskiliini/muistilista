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

    @AppStorage("lastStoreName") private var storeName = ""
    @State private var productName = ""
    @State private var results: [CatalogProduct] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var productFocused: Bool

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
            }
        }
    }

    private var storeSection: some View {
        Section("Kauppa") {
            Menu {
                ForEach(Stores.groups) { group in
                    Section(group.name) {
                        ForEach(group.stores, id: \.self) { name in
                            Button(name) { storeName = name; onStoreOrQueryChanged() }
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

    private var catalogResultsSection: some View {
        Section {
            if searching {
                HStack { ProgressView(); Text("Haetaan…").foregroundStyle(.secondary) }
            } else if !results.isEmpty {
                ForEach(results) { product in
                    Button { addCatalog(product) } label: { CatalogRow(product: product) }
                        .buttonStyle(.plain)
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

    /// Debounced catalog search whenever store or query changes.
    private func onStoreOrQueryChanged() {
        searchTask?.cancel()
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

    private func addCatalog(_ product: CatalogProduct) {
        // Shelf comes from the chain's own data (nil for stores that don't
        // publish it) — never typed by the user.
        insert(name: product.name, shelf: product.shelfLocation, catalog: product)
    }

    private func addManual() {
        guard let name = ShoppingListLogic.normalized(productName) else { return }
        insert(name: name, shelf: nil, catalog: nil)
    }

    /// Shared insert: item lands in the list's store and carries the
    /// catalog's price/description/images/shelf when present. Adding one
    /// item closes the store view and hands the new item's ID back so the
    /// list can scroll to it.
    private func insert(name: String, shelf: String?, catalog: CatalogProduct?) {
        guard let storeTrimmed = ShoppingListLogic.normalized(storeName) else { return }
        let item = CDShoppingItem(context: context)
        item.name = name
        item.storeName = storeTrimmed
        item.shelfLocation = shelf
        item.catalogPrice = catalog?.priceText
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
            Image(systemName: "plus.circle.fill").foregroundStyle(.tint)
        }
    }
}
