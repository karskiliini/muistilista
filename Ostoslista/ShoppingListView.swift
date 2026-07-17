import SwiftUI
import CoreData
import CloudKit
import UIKit

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
    @State private var storeQuery = ""
    @State private var scrollTarget: NSManagedObjectID?
    @State private var isRefreshing = false
    @State private var isSharing = false
    @State private var shareError: String?
    @State private var pendingCrash: CrashReport?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var sortedItems: [CDShoppingItem] { ShoppingListLogic.sorted(Array(items)) }
    private var checkedCount: Int { ShoppingListLogic.checked(Array(items)).count }

    /// Items grouped by store: named stores first (alphabetical), items
    /// without a store ("Muut") last. Each group keeps the unchecked-first
    /// order.
    private struct StoreGroup: Identifiable {
        let store: String            // "" for no-store
        let items: [CDShoppingItem]
        var id: String { store }
        var title: String { store.isEmpty ? "Muut" : store }
        var subtotal: Double { items.reduce(0) { $0 + $1.lineTotal } }
    }

    private var storeGroups: [StoreGroup] {
        let byStore = Dictionary(grouping: Array(items)) { $0.storeName ?? "" }
        return byStore
            .map { StoreGroup(store: $0.key, items: ShoppingListLogic.sorted($0.value)) }
            .sorted { a, b in
                if a.store.isEmpty != b.store.isEmpty { return !a.store.isEmpty } // "Muut" last
                return a.store.localizedCaseInsensitiveCompare(b.store) == .orderedAscending
            }
    }

    private var grandTotal: Double { items.reduce(0) { $0 + $1.lineTotal } }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                Section {
                    HStack {
                        TextField("Lisää tuote…", text: $newItemName)
                            .focused($inputFocused)
                            .submitLabel(.done)
                            .onSubmit(addItem)
                        Button {
                            // Carry whatever's been typed into the store search.
                            storeQuery = newItemName
                            newItemName = ""
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
                ForEach(storeGroups) { group in
                    Section {
                        ForEach(group.items) { item in
                            ShoppingRowView(item: item) {
                                item.isDone.toggle()
                                save()
                            }
                            .id(item.objectID)
                        }
                        .onDelete { offsets in deleteItems(from: group.items, at: offsets) }
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            Text("\(ShoppingListLogic.checked(group.items).count) / \(group.items.count)")
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        if let subtotal = ShoppingListLogic.priceText(group.subtotal) {
                            HStack {
                                Spacer()
                                Text("Yhteensä \(subtotal)").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if let total = ShoppingListLogic.priceText(grandTotal) {
                    Section {
                        HStack {
                            Text("Kaikki kaupat yhteensä").fontWeight(.semibold)
                            Spacer()
                            Text(total).fontWeight(.semibold).monospacedDigit()
                        }
                    }
                }
            }
            .animation(.default, value: items.count)
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                // Let the sheet finish dismissing and the row insert, then
                // scroll the new item into view with animation.
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    withAnimation(.spring(duration: 0.4)) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                    scrollTarget = nil
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
            .alert("Sovellus kaatui viime kerralla", isPresented: .constant(pendingCrash != nil)) {
                Button("Kopioi tiedot") {
                    if let c = pendingCrash {
                        UIPasteboard.general.string = c.summary + "\n\n" + c.stack.joined(separator: "\n")
                    }
                    CrashReporter.clearPending()
                    pendingCrash = nil
                }
                Button("Sulje", role: .cancel) {
                    CrashReporter.clearPending()
                    pendingCrash = nil
                }
            } message: {
                Text((pendingCrash?.summary ?? "") + "\n\nKopioi tiedot ja lähetä ne kehittäjälle syyn selvittämiseksi.")
            }
            .task { pendingCrash = CrashReporter.pending() }
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
                StoreAddView(initialQuery: storeQuery) { addedID in
                    scrollTarget = addedID
                }
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

    private func deleteItems(from groupItems: [CDShoppingItem], at offsets: IndexSet) {
        for index in offsets { context.delete(groupItems[index]) }
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
