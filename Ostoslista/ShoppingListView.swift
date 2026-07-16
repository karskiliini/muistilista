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
    @State private var isRefreshing = false
    @State private var isSharing = false
    @State private var shareError: String?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

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
                            Label("Hae kaupasta", systemImage: "storefront")
                                .labelStyle(.iconOnly)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
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
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Lista on tyhjä",
                        systemImage: "cart",
                        description: Text("Lisää tuote yltä kirjoittamalla, tai hae kaupasta \(Image(systemName: "storefront")) -painikkeella."))
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("Ostoslista")
            // Version pinned bottom-right without floating over rows: the
            // inset reserves its own strip so content never sits behind it.
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    Text("v\(appVersion)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
            }
            .refreshable {
                await store.forceRefresh()
            }
            .alert("Jakaminen epäonnistui", isPresented: .constant(shareError != nil)) {
                Button("OK") { shareError = nil }
            } message: {
                Text(shareError ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        guard !isRefreshing else { return }
                        Task {
                            isRefreshing = true
                            await store.forceRefresh()
                            isRefreshing = false
                        }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Label("Päivitä", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                    .keyboardShortcut("r", modifiers: .command)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        guard !isSharing else { return }
                        Task {
                            isSharing = true
                            defer { isSharing = false }
                            do {
                                let (share, container) = try await store.fetchOrCreateShare()
                                activeShare = share
                                shareContainer = container
                                sharePresented = true
                            } catch {
                                shareError = error.localizedDescription
                            }
                        }
                    } label: {
                        if isSharing {
                            ProgressView()
                        } else {
                            Label("Jaa perheelle", systemImage: "person.crop.circle.badge.plus")
                        }
                    }
                    .disabled(isSharing)
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
