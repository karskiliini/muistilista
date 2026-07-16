import SwiftUI
import CoreData

/// Optional store-based add flow (R23 phase A): pick a store, name the
/// product, optionally note the shelf. The family shelf memory pre-fills
/// the shelf when this (product, store) pair has been seen before.
/// Catalog providers (Kesko etc.) plug into this same sheet later.
struct StoreAddView: View {
    @EnvironmentObject private var store: StoreProvider
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("lastStoreName") private var storeName = ""
    @State private var productName = ""
    @State private var shelf = ""
    @State private var shelfWasRecalled = false
    @State private var addedCount = 0
    @FocusState private var productFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Kauppa") {
                    TextField("Kaupan nimi (esim. K-CM Kuopio)", text: $storeName)
                    let suggestions = store.knownStores().filter { $0 != storeName }
                    if storeName.isEmpty && !suggestions.isEmpty {
                        ForEach(suggestions.prefix(4), id: \.self) { name in
                            Button(name) { storeName = name }
                        }
                    }
                }
                Section("Tuote") {
                    TextField("Tuotteen nimi", text: $productName)
                        .focused($productFocused)
                        .onChange(of: productName) { _, newValue in
                            recallShelfIfKnown(for: newValue)
                        }
                    HStack {
                        TextField("Hyllypaikka (valinnainen)", text: $shelf)
                        if shelfWasRecalled {
                            Image(systemName: "brain")
                                .foregroundStyle(.tint)
                                .help("Perheen hyllymuistista")
                        }
                    }
                }
                Section {
                    Button("Lisää listalle", action: add)
                        .disabled(ShoppingListLogic.normalized(productName) == nil
                                  || ShoppingListLogic.normalized(storeName) == nil)
                } footer: {
                    if addedCount > 0 {
                        Text(addedCount == 1 ? "1 tuote lisätty" : "\(addedCount) tuotetta lisätty")
                    }
                }
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

    private func add() {
        guard let name = ShoppingListLogic.normalized(productName),
              let storeTrimmed = ShoppingListLogic.normalized(storeName) else { return }
        let item = CDShoppingItem(context: context)
        item.name = name
        item.storeName = storeTrimmed
        item.shelfLocation = ShoppingListLogic.normalized(shelf)
        if let list = store.currentList {
            if let listStore = list.objectID.persistentStore {
                context.assign(item, to: listStore)
            }
            item.list = list
        }
        try? context.save()
        store.rememberShelf(product: name, store: storeTrimmed, shelf: shelf)
        addedCount += 1
        productName = ""
        shelf = ""
        shelfWasRecalled = false
        productFocused = true
    }
}
