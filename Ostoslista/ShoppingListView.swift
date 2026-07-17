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

    // Custom store drag. All positions are in the List's "list" space.
    @State private var dragItem: NSManagedObjectID?          // item being dragged
    @State private var dragLocation: CGPoint = .zero          // finger position
    @State private var dragStartStore = ""                    // its store at grab time
    @State private var dragSnapshot: [CGFloat] = []           // sibling row midYs (fixed)
    @State private var dragTargetStore: String?               // live drop store
    @State private var dragTargetIndex = 0                    // live drop slot in store
    @State private var rowFrames: [RowFrame] = []             // live row extents

    private var isUITest: Bool { ProcessInfo.processInfo.arguments.contains("-UITestReset") }
    private var isDragging: Bool { dragItem != nil }

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

    /// A signature that changes whenever the rendered layout should re-animate:
    /// each item's store/checked/order, plus the live drag target.
    private var layoutSignature: String {
        let base = displayGroups.flatMap { g in
            g.items.map { "\($0.objectID.uriRepresentation().lastPathComponent):\(g.store):\($0.isDone ? 1 : 0)" }
        }.joined(separator: "|")
        return base + "#\(dragTargetStore ?? "-"):\(dragTargetIndex)"
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

    /// The groups the List renders. While dragging a (free) item this differs
    /// from the stored grouping: the dragged item is shown at its live target
    /// position (so rows make room for it in real time), and a "Muut"
    /// (no-store) drop zone is always surfaced at the bottom — even when empty
    /// — so the item can always be dropped back to no store.
    private var displayGroups: [StoreGroup] {
        // Where each item displays; the dragged one follows the finger.
        func displayStore(_ item: CDShoppingItem) -> String {
            if isDragging, item.objectID == dragItem, let target = dragTargetStore { return target }
            return item.storeName ?? ""
        }
        var byStore = Dictionary(grouping: Array(items)) { displayStore($0) }
        if isDragging, byStore[""] == nil { byStore[""] = [] }   // always offer "Ei kauppaa"
        return byStore.map { key, groupItems -> StoreGroup in
            var ordered = ShoppingListLogic.sorted(groupItems)
            // Slot the dragged item into its live target index within its store.
            if isDragging, let dragItem, dragTargetStore == key,
               let idx = ordered.firstIndex(where: { $0.objectID == dragItem }) {
                let moved = ordered.remove(at: idx)
                ordered.insert(moved, at: max(0, min(dragTargetIndex, ordered.count)))
            }
            return StoreGroup(store: key, items: ordered)
        }
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
                ForEach(displayGroups) { group in
                    Section {
                        if group.items.isEmpty {
                            // Empty drop zone shown only during a drag.
                            DropZonePlaceholder(store: group.store)
                        }
                        ForEach(group.items) { item in
                            ShoppingRowView(
                                item: item,
                                onToggle: { item.isDone.toggle(); save() },
                                onStoreDrag: handleStoreDrag,
                                onStoreDrop: handleStoreDrop)
                            .id(item.objectID)
                            .opacity(dragItem == item.objectID ? 0.5
                                     : (recentlyMoved == item.objectID ? 0.5 : 1))
                            // Lift the dragged row so it reads as picked up.
                            .scaleEffect(dragItem == item.objectID ? 1.03 : 1, anchor: .leading)
                            .shadow(color: .black.opacity(dragItem == item.objectID ? 0.18 : 0),
                                    radius: 6, y: 3)
                            .zIndex(dragItem == item.objectID ? 1 : 0)
                            // Report each row's extent so the drag can be
                            // hit-tested against store sections and slots.
                            .background(GeometryReader { geo in
                                Color.clear.preference(
                                    key: RowFrameKey.self,
                                    value: [RowFrame(store: group.store, id: item.objectID,
                                                     rect: geo.frame(in: .global))])
                            })
                        }
                        .onDelete { offsets in deleteItems(from: group.items, at: offsets) }
                    } header: {
                        StoreGroupHeader(
                            title: group.title,
                            countText: group.items.isEmpty ? ""
                                : "\(ShoppingListLogic.checked(group.items).count) / \(group.items.count)",
                            highlighted: isDragging && dragTargetStore == group.store)
                    } footer: {
                        if !isDragging, let subtotal = ShoppingListLogic.priceText(group.subtotal) {
                            HStack {
                                Spacer()
                                Text("Yhteensä \(subtotal)").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if !isDragging, let total = ShoppingListLogic.priceText(grandTotal) {
                    Section {
                        HStack {
                            Text("Kaikki kaupat yhteensä").fontWeight(.semibold)
                            Spacer()
                            Text(total).fontWeight(.semibold).monospacedDigit()
                        }
                    }
                }
            }
            // Animate rows making room as the drag target moves, and items
            // flowing between store groups, by keying on the layout signature.
            .animation(.spring(duration: 0.3), value: layoutSignature)
            .onPreferenceChange(RowFrameKey.self) { rowFrames = $0 }
            // Floating ghost of the dragged item, tracking the finger. The
            // finger position is in global space, so convert it into this
            // overlay's local space via its own global origin.
            .overlay {
                if let dragItem, let item = itemByID(dragItem) {
                    GeometryReader { geo in
                        let origin = geo.frame(in: .global).origin
                        DragPreview(item: item)
                            .position(x: dragLocation.x - origin.x,
                                      y: dragLocation.y - origin.y)
                    }
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
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

    /// Drag in progress: on the first callback capture a fixed snapshot of the
    /// item's sibling positions (so reordering never feeds back into itself),
    /// then update the live target as the finger moves.
    private func handleStoreDrag(_ id: NSManagedObjectID, _ location: CGPoint) {
        if dragItem != id {
            dragItem = id
            dragStartStore = itemByID(id)?.storeName ?? ""
            dragSnapshot = rowFrames
                .filter { $0.store == dragStartStore }
                .filter { frame in frame.id.map { !$0.isEqual(id) } ?? false }
                .map(\.rect.midY)
                .sorted()
            dragTargetStore = dragStartStore
        }
        dragLocation = location
        updateDragTarget(location)
    }

    /// Recompute where the item would land: which store section the finger is
    /// over, and — when that's the item's own store — the slot within it.
    private func updateDragTarget(_ location: CGPoint) {
        let target = store(atY: location.y) ?? dragStartStore
        dragTargetStore = target
        if target == dragStartStore {
            // Reorder within the original store using the fixed snapshot.
            dragTargetIndex = dragSnapshot.filter { $0 < location.y }.count
        } else {
            // Into another store: append at the end.
            dragTargetIndex = Int.max
        }
    }

    /// Drag released: commit the live target to the data model.
    private func handleStoreDrop(_ id: NSManagedObjectID, _ location: CGPoint) {
        updateDragTarget(location)
        let target = dragTargetStore ?? dragStartStore
        let index = dragTargetIndex
        let moved = commitDrag(id: id, toStore: target, index: index)
        withAnimation(.spring(duration: 0.3)) { endDrag() }
        if isUITest {
            let idx = index == Int.max ? -1 : index
            dropDebug = "store:\(target.isEmpty ? "-" : target):i\(idx):m\(moved)"
        }
    }

    /// Reassign the item to `store` and renumber that group so the item sits at
    /// `index`. Catalog items stay locked. Returns 1 when it moved.
    @discardableResult
    private func commitDrag(id: NSManagedObjectID, toStore store: String, index: Int) -> Int {
        guard let item = itemByID(id), item.canChangeStore else { return 0 }
        item.storeName = store.isEmpty ? nil : store
        // Renumber the destination group so the drag order persists.
        let groupIDs = ShoppingListLogic
            .sorted(Array(items).filter { ($0.storeName ?? "") == store })
            .map(\.objectID)
        let newOrder = ShoppingListLogic.reordered(groupIDs, move: id, to: index)
        for (position, oid) in newOrder.enumerated() {
            itemByID(oid)?.sortOrder = Double(position)
        }
        save()
        scrollTarget = id
        recentlyMoved = id
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            if recentlyMoved == id { recentlyMoved = nil }
        }
        return 1
    }

    private func endDrag() {
        dragItem = nil
        dragTargetStore = nil
        dragSnapshot = []
        dragTargetIndex = 0
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

/// A row's store, item id (nil for an empty drop zone) and its vertical extent
/// in "list" space, collected so a store drag can be hit-tested against the
/// sections and slots.
private struct RowFrame: Equatable {
    let store: String
    let id: NSManagedObjectID?
    let rect: CGRect

    static func == (a: RowFrame, b: RowFrame) -> Bool {
        a.store == b.store && a.rect == b.rect
            && (a.id?.isEqual(b.id) ?? (b.id == nil))
    }
}

private struct RowFrameKey: PreferenceKey {
    static var defaultValue: [RowFrame] = []
    static func reduce(value: inout [RowFrame], nextValue: () -> [RowFrame]) {
        value.append(contentsOf: nextValue())
    }
}

/// Empty store section shown only during a drag, so a free item can be dropped
/// into a store that has no items yet — or back to "Muut" (no store).
private struct DropZonePlaceholder: View {
    let store: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
            Text("Pudota tähän").font(.subheadline)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(GeometryReader { geo in
            Color.clear.preference(
                key: RowFrameKey.self,
                value: [RowFrame(store: store, id: nil, rect: geo.frame(in: .global))])
        })
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
