import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [ShoppingItem]
    @State private var newItemName = ""
    @FocusState private var inputFocused: Bool

    private var sortedItems: [ShoppingItem] { ShoppingListLogic.sorted(items) }
    private var checkedCount: Int { ShoppingListLogic.checked(items).count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Lisää tuote…", text: $newItemName)
                        .focused($inputFocused)
                        .submitLabel(.done)
                        .onSubmit(addItem)
                }
                if !items.isEmpty {
                    Section {
                        ForEach(sortedItems) { item in
                            ShoppingRowView(item: item) { item.isDone.toggle() }
                        }
                        .onDelete(perform: deleteItems)
                    } header: {
                        Text("\(checkedCount) / \(items.count)")
                    }
                }
            }
            .navigationTitle("Ostoslista")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tyhjennä ostetut", action: clearChecked)
                        .disabled(checkedCount == 0)
                }
            }
        }
    }

    private func addItem() {
        guard let name = ShoppingListLogic.normalized(newItemName) else { return }
        modelContext.insert(ShoppingItem(name: name))
        newItemName = ""
        inputFocused = true
    }

    private func deleteItems(at offsets: IndexSet) {
        let current = sortedItems
        for index in offsets { modelContext.delete(current[index]) }
    }

    private func clearChecked() {
        for item in ShoppingListLogic.checked(items) { modelContext.delete(item) }
    }
}
