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
    @State private var addedCount = 0
    @State private var newStorePromptShown = false
    @State private var newStoreName = ""
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
            .alert("Uusi kauppa", isPresented: $newStorePromptShown) {
                TextField("Kaupan nimi (esim. Prisma Kuopio)", text: $newStoreName)
                Button("Valitse") {
                    if let name = ShoppingListLogic.normalized(newStoreName) { storeName = name }
                    newStoreName = ""
                }
                Button("Peruuta", role: .cancel) { newStoreName = "" }
            }
        }
    }

    private var storeSection: some View {
        Section("Kauppa") {
            Menu {
                ForEach(storeChoices, id: \.self) { name in
                    Button(name) { storeName = name; onStoreOrQueryChanged() }
                }
                if !storeChoices.isEmpty { Divider() }
                Button("Uusi kauppa…") { newStorePromptShown = true }
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
                if shelfWasRecalled {
                    Image(systemName: "brain").foregroundStyle(.tint)
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

    private var storeChoices: [String] {
        var names = store.knownStores()
        if !storeName.isEmpty && !names.contains(storeName) { names.insert(storeName, at: 0) }
        return names
    }

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
        shelf = known
        shelfWasRecalled = true
    }

    private func addCatalog(_ product: CatalogProduct) {
        insert(name: product.name,
               shelfHint: shelf.isEmpty ? ShoppingListLogic.categoryHint(product.categoryPath) : shelf)
    }

    private func addManual() {
        guard let name = ShoppingListLogic.normalized(productName) else { return }
        insert(name: name, shelfHint: ShoppingListLogic.normalized(shelf))
    }

    /// Shared insert: item lands in the list's store, remembers the shelf.
    private func insert(name: String, shelfHint: String?) {
        guard let storeTrimmed = ShoppingListLogic.normalized(storeName) else { return }
        let item = CDShoppingItem(context: context)
        item.name = name
        item.storeName = storeTrimmed
        item.shelfLocation = shelfHint
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
            AsyncImage(url: product.imageURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "photo").foregroundStyle(.quaternary)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(.subheadline)
                if let hint = ShoppingListLogic.categoryHint(product.categoryPath) {
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
