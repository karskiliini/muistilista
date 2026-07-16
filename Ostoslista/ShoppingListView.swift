import SwiftUI
import CoreData

struct ShoppingListView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var store: StoreProvider
    @FetchRequest(sortDescriptors: [SortDescriptor(\CDShoppingItem.createdAt)])
    private var items: FetchedResults<CDShoppingItem>
    @State private var newItemName = ""
    @FocusState private var inputFocused: Bool

    private var sortedItems: [CDShoppingItem] { ShoppingListLogic.sorted(Array(items)) }
    private var checkedCount: Int { ShoppingListLogic.checked(Array(items)).count }

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
                            ShoppingRowView(item: item) {
                                item.isDone.toggle()
                                save()
                            }
                        }
                        .onDelete(perform: deleteItems)
                    } header: {
                        Text("\(checkedCount) / \(items.count)")
                    }
                }
            }
            .navigationTitle("Ostoslista")
            .refreshable {
                await store.forceRefresh()
            }
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
        let item = CDShoppingItem(context: context)
        item.name = name
        save()
        newItemName = ""
        inputFocused = true
    }

    private func deleteItems(at offsets: IndexSet) {
        let current = sortedItems
        for index in offsets { context.delete(current[index]) }
        save()
    }

    private func clearChecked() {
        for item in ShoppingListLogic.checked(Array(items)) { context.delete(item) }
        save()
    }

    private func save() {
        try? context.save()
    }
}
