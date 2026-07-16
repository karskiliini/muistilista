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
    @State private var newStorePromptShown = false
    @State private var newStoreName = ""
    @FocusState private var productFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Kauppa") {
                    Menu {
                        ForEach(storeChoices, id: \.self) { name in
                            Button(name) { storeName = name }
                        }
                        if !storeChoices.isEmpty { Divider() }
                        Button("Uusi kauppa…") { newStorePromptShown = true }
                    } label: {
                        HStack {
                            Text(storeName.isEmpty ? "Valitse kauppa" : storeName)
                                .foregroundStyle(storeName.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
            .alert("Uusi kauppa", isPresented: $newStorePromptShown) {
                TextField("Kaupan nimi (esim. K-CM Kuopio)", text: $newStoreName)
                Button("Valitse") {
                    if let name = ShoppingListLogic.normalized(newStoreName) {
                        storeName = name
                    }
                    newStoreName = ""
                }
                Button("Peruuta", role: .cancel) { newStoreName = "" }
            }
        }
    }

    /// Dropdown contents: the current store first, then other known ones.
    private var storeChoices: [String] {
        var names = store.knownStores()
        if !storeName.isEmpty && !names.contains(storeName) {
            names.insert(storeName, at: 0)
        }
        return names
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
