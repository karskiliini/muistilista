import SwiftUI
import CoreData

/// Optional store-based add flow (R23): pick a store, then either search
/// the store's live catalog (S-group today) or type freely. Catalog hits
/// show price + category; tapping one adds it. The family shelf memory
/// supplies the physical shelf location the catalog can't.
struct StoreAddView: View {
    @EnvironmentObject private var store: StoreProvider
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("lastStoreName") private var storeName = ""
    @State private var productName = ""
    @State private var shelf = ""
    @State private var shelfWasRecalled = false
    @State private var recalledShelfValue = ""
    @State private var addedCount = 0
    @State private var results: [CatalogProduct] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var productFocused: Bool

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
                .onChange(of: productName) { _, _ in onStoreOrQueryChanged() }
            HStack {
                TextField("Hyllypaikka (valinnainen)", text: $shelf)
                    .onChange(of: shelf) { _, new in
                        // A hand edit (value differs from what recall filled
                        // in) means it's no longer the remembered value.
                        if shelfWasRecalled && new != recalledShelfValue {
                            shelfWasRecalled = false
                        }
                    }
                if shelfWasRecalled {
                    Image(systemName: "brain")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Perheen hyllymuistista")
                }
            }
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
            Text("S-valikoima")
        } footer: {
            Text("Hinnat viitteellisiä (edustava S-kauppa). Hyllypaikka tallentuu perheen muistiin, kun annat sen.")
        }
    }

    private var addSection: some View {
        Section {
            Button(catalog != nil ? "Lisää vapaana tekstinä" : "Lisää listalle") { addManual() }
                .disabled(ShoppingListLogic.normalized(productName) == nil
                          || ShoppingListLogic.normalized(storeName) == nil)
        } footer: {
            if addedCount > 0 {
                Text(addedCount == 1 ? "1 tuote lisätty" : "\(addedCount) tuotetta lisätty")
            }
        }
    }

    // MARK: - Behavior

    /// Debounced catalog search + shelf recall whenever store or query changes.
    private func onStoreOrQueryChanged() {
        recallShelfIfKnown(for: productName)
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

    private func recallShelfIfKnown(for product: String) {
        guard shelf.isEmpty || shelfWasRecalled,
              let name = ShoppingListLogic.normalized(product),
              let known = store.recallShelf(product: name, store: storeName) else {
            if shelfWasRecalled { shelf = ""; shelfWasRecalled = false }
            return
        }
        recalledShelfValue = known
        shelf = known
        shelfWasRecalled = true
    }

    private func addCatalog(_ product: CatalogProduct) {
        // Real shelf from the chain wins; else the shelf the user typed;
        // else the category breadcrumb as a coarse hint.
        let shelfHint = product.shelfLocation
            ?? (shelf.isEmpty ? ShoppingListLogic.categoryHint(product.categoryPath) : shelf)
        insert(name: product.name, shelfHint: shelfHint, catalog: product)
    }

    private func addManual() {
        guard let name = ShoppingListLogic.normalized(productName) else { return }
        insert(name: name, shelfHint: ShoppingListLogic.normalized(shelf), catalog: nil)
    }

    /// Shared insert: item lands in the list's store, remembers the shelf,
    /// and carries the catalog's price/description/images when present.
    private func insert(name: String, shelfHint: String?, catalog: CatalogProduct?) {
        guard let storeTrimmed = ShoppingListLogic.normalized(storeName) else { return }
        let item = CDShoppingItem(context: context)
        item.name = name
        item.storeName = storeTrimmed
        item.shelfLocation = shelfHint
        item.catalogPrice = catalog?.priceText
        item.productDescription = catalog?.description
        item.imageURLsString = catalog?.imageURLs.map(\.absoluteString).joined(separator: "\n")
        if let list = store.currentList {
            if let listStore = list.objectID.persistentStore { context.assign(item, to: listStore) }
            item.list = list
        }
        try? context.save()
        store.rememberShelf(product: name, store: storeTrimmed, shelf: shelf)
        addedCount += 1
        productName = ""; shelf = ""; shelfWasRecalled = false; results = []
        productFocused = true
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
