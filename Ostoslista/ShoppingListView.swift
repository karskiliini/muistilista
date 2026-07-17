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
    @State private var dropDebug = "d0m0"   // UI-test drop diagnostics

    // Custom store drag: the item being dragged, the finger position, and the
    // captured vertical extents of every row (all in the List's "list" space).
    @State private var dragItem: NSManagedObjectID?
    @State private var dragLocation: CGPoint = .zero
    @State private var rowFrames: [RowFrame] = []

    private var isUITest: Bool { ProcessInfo.processInfo.arguments.contains("-UITestReset") }

    /// The store whose rows the finger is currently over (nil = not dragging).
    private var hoverStore: String? {
        guard dragItem != nil else { return nil }
        return store(atY: dragLocation.y)
    }

    /// Map a Y position in "list" space onto a store, clamping to the nearest
    /// section when the finger is above the first or below the last row.
    private func store(atY y: CGFloat) -> String? {
        if let hit = rowFrames.first(where: { $0.rect.minY <= y && y <= $0.rect.maxY }) {
            return hit.store
        }
        guard let first = rowFrames.min(by: { $0.rect.midY < $1.rect.midY }),
              let last = rowFrames.max(by: { $0.rect.midY < $1.rect.midY }) else { return nil }
        return y < first.rect.minY ? first.store : last.store
    }

    private func itemByID(_ id: NSManagedObjectID) -> CDShoppingItem? {
        items.first { $0.objectID == id }
    }

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
                            ShoppingRowView(
                                item: item,
                                onToggle: { item.isDone.toggle(); save() },
                                onStoreDrag: handleStoreDrag,
                                onStoreDrop: handleStoreDrop)
                            .id(item.objectID)
                            .opacity(dragItem == item.objectID ? 0.35
                                     : (recentlyMoved == item.objectID ? 0.5 : 1))
                            // Report each row's vertical extent so a drag can be
                            // hit-tested against store sections.
                            .background(GeometryReader { geo in
                                Color.clear.preference(
                                    key: RowFrameKey.self,
                                    value: [RowFrame(store: group.store,
                                                     rect: geo.frame(in: .named("list")))])
                            })
                        }
                        .onDelete { offsets in deleteItems(from: group.items, at: offsets) }
                    } header: {
                        StoreGroupHeader(
                            title: group.title,
                            countText: "\(ShoppingListLogic.checked(group.items).count) / \(group.items.count)",
                            highlighted: dragItem != nil && hoverStore == group.store)
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
            .coordinateSpace(name: "list")
            .onPreferenceChange(RowFrameKey.self) { rowFrames = $0 }
            // Floating preview of the dragged item, tracking the finger.
            .overlay(alignment: .topLeading) {
                if let dragItem, let item = itemByID(dragItem) {
                    DragPreview(item: item)
                        .position(x: dragLocation.x, y: dragLocation.y)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
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
                    Text(isUITest ? "v\(appVersion) \(dropDebug)" : "v\(appVersion)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityIdentifier("debug-drop")
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

    /// Drag in progress: remember the item and follow the finger.
    private func handleStoreDrag(_ id: NSManagedObjectID, _ location: CGPoint) {
        if dragItem != id { dragItem = id }
        dragLocation = location
    }

    /// Drag released: move the item to whichever store section it was dropped
    /// on, then center the moved row.
    private func handleStoreDrop(_ id: NSManagedObjectID, _ location: CGPoint) {
        let target = store(atY: location.y)
        withAnimation { dragItem = nil }
        let moved = target.map { moveItem(id, toStore: $0) } ?? 0
        if isUITest { dropDebug = "d\(target == nil ? 0 : 1)m\(moved)" }
    }

    /// Reassign an item to a store ("" = "Muut"); catalog items stay locked.
    @discardableResult
    private func moveItem(_ id: NSManagedObjectID, toStore store: String) -> Int {
        guard let item = try? context.existingObject(with: id) as? CDShoppingItem,
              item.canChangeStore else { return 0 }
        item.storeName = store.isEmpty ? nil : store
        save()   // the List's groupSignature animation flows the row over
        scrollTarget = id
        recentlyMoved = id
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            if recentlyMoved == id { recentlyMoved = nil }
        }
        return 1
    }

    private func clearChecked() {
        for item in ShoppingListLogic.checked(Array(items)) { context.delete(item) }
        save()
    }

    private func save() {
        try? context.save()
    }
}

/// Store section header that highlights while an item is being dragged over
/// this store's section.
private struct StoreGroupHeader: View {
    let title: String
    let countText: String
    let highlighted: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(countText).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .background(highlighted ? Color.accentColor.opacity(0.18) : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .animation(.easeInOut(duration: 0.15), value: highlighted)
    }
}

/// A row's store and its vertical extent in "list" space, collected so a
/// store drag can be hit-tested against the sections.
private struct RowFrame: Equatable {
    let store: String
    let rect: CGRect
}

private struct RowFrameKey: PreferenceKey {
    static var defaultValue: [RowFrame] = []
    static func reduce(value: inout [RowFrame], nextValue: () -> [RowFrame]) {
        value.append(contentsOf: nextValue())
    }
}

/// The floating bubble shown under the finger while dragging an item to a
/// new store.
private struct DragPreview: View {
    @ObservedObject var item: CDShoppingItem

    var body: some View {
        HStack(spacing: 8) {
            if item.isFromStore, let url = item.imageURLs.first {
                CachedAsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "cart").foregroundStyle(.tint)
            }
            Text(item.name).lineLimit(1)
            if item.quantity > 1 { Text("× \(item.quantity)").foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 6, y: 3)
    }
}
