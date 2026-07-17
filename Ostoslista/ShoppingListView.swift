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
    @State private var recentlyMoved: NSManagedObjectID?
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

    /// Changes whenever any item's store/checked state changes, so the List
    /// animates moves between groups.
    private var groupSignature: String {
        items.map { "\($0.objectID.uriRepresentation().lastPathComponent):\($0.storeName ?? "-"):\($0.isDone ? 1 : 0)" }
            .sorted().joined(separator: "|")
    }

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
                            .opacity(recentlyMoved == item.objectID ? 0.5 : 1)
                        }
                        .onDelete { offsets in deleteItems(from: group.items, at: offsets) }
                    } header: {
                        StoreGroupHeader(
                            title: group.title,
                            countText: "\(ShoppingListLogic.checked(group.items).count) / \(group.items.count)",
                            onDropURIs: { uris in moveDropped(uris, toStore: group.store) })
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
            // Animate section/row changes — including an item moving to a new
            // store group — by keying on a signature that captures store,
            // checked state and order for every item.
            .animation(.spring(duration: 0.35), value: groupSignature)
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

    /// Reassign dropped items (carried as objectID URI strings) to a store,
    /// then center the moved item.
    private func moveDropped(_ uris: [String], toStore store: String) {
        guard let coordinator = context.persistentStoreCoordinator else { return }
        var moved: NSManagedObjectID?
        for uri in uris {
            guard let url = URL(string: uri),
                  let oid = coordinator.managedObjectID(forURIRepresentation: url),
                  let item = try? context.existingObject(with: oid) as? CDShoppingItem,
                  item.canChangeStore else { continue }   // catalog items are locked
            item.storeName = store.isEmpty ? nil : store
            moved = item.objectID
        }
        save()   // the List's groupSignature animation flows the row over
        if let moved {
            scrollTarget = moved
            recentlyMoved = moved
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                if recentlyMoved == moved { recentlyMoved = nil }
            }
        }
    }

    private func clearChecked() {
        for item in ShoppingListLogic.checked(Array(items)) { context.delete(item) }
        save()
    }

    private func save() {
        try? context.save()
    }
}

/// Store section header that highlights when an item is dragged over it and
/// reassigns the dropped item to this store.
private struct StoreGroupHeader: View {
    let title: String
    let countText: String
    let onDropURIs: ([String]) -> Void
    @State private var targeted = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(countText).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .background(targeted ? Color.accentColor.opacity(0.18) : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .dropDestination(for: String.self) { uris, _ in
            onDropURIs(uris)
            return true
        } isTargeted: { targeted = $0 }
    }
}
