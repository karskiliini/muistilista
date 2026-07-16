import SwiftUI
import CoreData
import CloudKit

struct ShoppingListView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var store: StoreProvider
    @FetchRequest(sortDescriptors: [SortDescriptor(\CDShoppingItem.createdAt)])
    private var items: FetchedResults<CDShoppingItem>
    @State private var newItemName = ""
    @FocusState private var inputFocused: Bool
    @State private var activeShare: CKShare?
    @State private var shareContainer: CKContainer?
    @State private var sharePresented = false
    @State private var storeAddPresented = false

    private var sortedItems: [CDShoppingItem] { ShoppingListLogic.sorted(Array(items)) }
    private var checkedCount: Int { ShoppingListLogic.checked(Array(items)).count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Lisää tuote…", text: $newItemName)
                            .focused($inputFocused)
                            .submitLabel(.done)
                            .onSubmit(addItem)
                        Button {
                            storeAddPresented = true
                        } label: {
                            Label("Kauppa", systemImage: "storefront")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                    }
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
            .overlay(alignment: .bottomTrailing) {
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 8)
                    .padding(.bottom, 2)
            }
            .refreshable {
                await store.forceRefresh()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await store.forceRefresh() }
                    } label: {
                        Label("Päivitä", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task {
                            if let (share, container) = try? await store.fetchOrCreateShare() {
                                activeShare = share
                                shareContainer = container
                                sharePresented = true
                            }
                        }
                    } label: {
                        Label("Jaa perheelle", systemImage: "person.crop.circle.badge.plus")
                    }
                    Button("Tyhjennä ostetut", action: clearChecked)
                        .disabled(checkedCount == 0)
                }
            }
            .sheet(isPresented: $sharePresented) {
                if let activeShare, let shareContainer {
                    CloudSharingView(share: activeShare, container: shareContainer)
                }
            }
            .sheet(isPresented: $storeAddPresented) {
                StoreAddView()
            }
        }
    }

    private func addItem() {
        guard let name = ShoppingListLogic.normalized(newItemName) else { return }
        let item = CDShoppingItem(context: context)
        item.name = name
        // New items must land in the same store as the list they belong to
        // (a family member's list lives in the shared store).
        if let list = store.currentList {
            if let listStore = list.objectID.persistentStore {
                context.assign(item, to: listStore)
            }
            item.list = list
        }
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
