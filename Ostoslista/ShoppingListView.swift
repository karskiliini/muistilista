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
    // Finger position lives in a separate observable that ONLY the ghost view
    // watches, so updating it every frame does NOT re-render the List (held via
    // @State, which doesn't subscribe to its @Published — by design).
    @State private var dragState = DragState()
    @State private var dragStartStore = ""                    // its store at grab time
    // Fixed snapshot of every OTHER row's (store, midY), captured once the
    // drag layout settles. Hit-testing against this — not the live, shifting
    // layout — lets the item move live between sections without the finger's
    // target oscillating (which hung the app).
    @State private var dragSlots: [DragSlot] = []
    @State private var dragTargetStore: String?               // live drop store
    @State private var dragTargetIndex = 0                    // live drop slot in store
    // Live row extents, held in a reference type so frame updates (which fire
    // every animation frame) DON'T re-run `body`. Storing them in @State would
    // re-render on every update, re-emitting the frame preferences, which never
    // settle (sub-pixel jitter) — a tight loop that hangs the main thread.
    @State private var frames = RowFrameStore()

    private var isUITest: Bool { ProcessInfo.processInfo.arguments.contains("-UITestReset") }
    private var isDragging: Bool { dragItem != nil }

    private func itemByID(_ id: NSManagedObjectID) -> CDShoppingItem? {
        items.first { $0.objectID == id }
    }

    /// Light tactile feedback for key interactions (no-op in the Simulator).
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// A signature that changes whenever the rendered layout should re-animate:
    /// each item's store/checked/order, plus the live drag target. Built
    /// straight from `items` (cheap) rather than from `displayGroups`, so it
    /// doesn't re-run the grouping/sorting on every `body` pass.
    private var layoutSignature: String {
        items.map {
            "\($0.objectID.uriRepresentation().lastPathComponent):\($0.storeName ?? "-"):\($0.isDone ? 1 : 0):\(Int($0.sortOrder))"
        }.joined(separator: "|") + "#\(dragTargetStore ?? "-"):\(dragTargetIndex)"
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

    /// The groups the List renders. While dragging, the item is shown live at
    /// its target position — sliding to a new slot within its category or into
    /// another category — so the move is visible in real time. This is safe
    /// because the target is hit-tested against a FIXED snapshot (`dragSlots`),
    /// so the item moving can't shift the hit-test and oscillate. A "Muut"
    /// (no-store) drop zone is always surfaced at the bottom during a drag.
    private var displayGroups: [StoreGroup] {
        var byStore = Dictionary(grouping: Array(items)) { $0.storeName ?? "" }
        if isDragging, byStore[""] == nil { byStore[""] = [] }   // always offer "Ei kauppaa"
        // Live reorder only WITHIN the dragged item's own store (same section →
        // the drag gesture survives). Cross-section moves would recreate the
        // row's cell and cancel the gesture, so those are shown via a preview.
        let reorderStore = (isDragging && dragTargetStore == dragStartStore) ? dragStartStore : nil
        return byStore.map { key, groupItems -> StoreGroup in
            var ordered = ShoppingListLogic.sorted(groupItems)
            if let reorderStore, reorderStore == key, let dragItem,
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

    /// Dragging toward a DIFFERENT store than the item's own.
    private var isCrossCategoryDrag: Bool {
        isDragging && dragTargetStore != nil && dragTargetStore != dragStartStore
    }

    /// Rows to render for a section: its real items, plus — for a cross-category
    /// drag targeting this section — a sliding preview at the target slot.
    private func sectionRows(for group: StoreGroup) -> [RowSpec] {
        var specs = group.items.map { RowSpec.real($0) }
        if isCrossCategoryDrag, dragTargetStore == group.store,
           let dragItem, let item = itemByID(dragItem) {
            specs.insert(.preview(item), at: max(0, min(dragTargetIndex, specs.count)))
        }
        return specs
    }

    /// The dragged row fades while reordering (it's the visual) or fades further
    /// while moving to another store (the preview is the visual instead).
    private func rowOpacity(_ item: CDShoppingItem) -> Double {
        if dragItem == item.objectID { return isCrossCategoryDrag ? 0.3 : 0.5 }
        return recentlyMoved == item.objectID ? 0.5 : 1
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
                        ForEach(sectionRows(for: group)) { spec in
                            switch spec {
                            case .real(let item):
                                ShoppingRowView(
                                    item: item,
                                    onToggle: { item.isDone.toggle(); haptic(.light); save() },
                                    onStoreDrag: handleStoreDrag,
                                    onStoreDrop: handleStoreDrop)
                                .id(item.objectID)
                                // While being dragged to ANOTHER store the row
                                // stays here (so the gesture survives) but fades
                                // out — the sliding preview carries the visual.
                                .opacity(rowOpacity(item))
                                .scaleEffect(dragItem == item.objectID && !isCrossCategoryDrag ? 1.03 : 1,
                                             anchor: .leading)
                                .zIndex(dragItem == item.objectID ? 1 : 0)
                                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 10))
                                .background(GeometryReader { geo in
                                    Color.clear.preference(
                                        key: RowFrameKey.self,
                                        value: [RowFrame(store: group.store, id: item.objectID,
                                                         rect: geo.frame(in: .global))])
                                })
                            case .preview(let item):
                                ShoppingRowView(item: item, onToggle: {})
                                    .opacity(0.55)
                                    .allowsHitTesting(false)
                                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 10))
                            }
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
            .environment(\.defaultMinListRowHeight, 36)   // allow short rows
            // Silently stash frames (no re-render — see `frames` declaration).
            .onPreferenceChange(RowFrameKey.self) { frames.rows = $0 }
            // Floating ghost of the dragged item, tracking the finger. It lives
            // in its own view observing `dragState`, so the finger moving
            // re-renders ONLY the ghost — the List re-renders solely when the
            // drop target changes slot/section (not every frame), which is what
            // keeps a cross-section drag from flooding the List and hanging.
            .overlay {
                DragGhostOverlay(dragState: dragState,
                                 item: dragItem.flatMap { itemByID($0) })
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

    /// Drag in progress. The first callback just records the item; the layout
    /// then re-lays-out into drag mode, and on the next callback we capture the
    /// fixed slot snapshot. Every later callback maps the finger onto a target
    /// using that fixed snapshot, so moving the item never shifts the hit-test.
    private func handleStoreDrag(_ id: NSManagedObjectID, _ location: CGPoint) {
        dragState.location = location   // moves the ghost only (no List re-render)
        if dragItem != id {
            dragItem = id
            dragStartStore = itemByID(id)?.storeName ?? ""
            dragSlots = []
            dragTargetStore = dragStartStore
            dragTargetIndex = currentIndex(of: id, inStore: dragStartStore)
            haptic(.rigid)   // "lift"
            return
        }
        if dragSlots.isEmpty { dragSlots = captureSlots(excluding: id) }
        updateDragTarget(id: id, at: location)
    }

    /// The item's current position within its store (so the drag starts with
    /// the row exactly where it already is).
    private func currentIndex(of id: NSManagedObjectID, inStore store: String) -> Int {
        ShoppingListLogic.sorted(Array(items).filter { ($0.storeName ?? "") == store })
            .firstIndex { $0.objectID == id } ?? 0
    }

    /// Snapshot of every other row's (store, midY) — plus empty drop zones —
    /// in the drag-mode layout. Fixed for the whole drag.
    private func captureSlots(excluding id: NSManagedObjectID) -> [DragSlot] {
        frames.rows
            .filter { $0.id.map { !$0.isEqual(id) } ?? true }   // keep others + zones
            .map { DragSlot(store: $0.store, midY: $0.rect.midY) }
            .sorted { $0.midY < $1.midY }
    }

    /// Map the finger onto a target store + slot using the FIXED snapshot.
    /// Catalog items are pinned to their own store (reorder only).
    private func updateDragTarget(id: NSManagedObjectID, at location: CGPoint) {
        guard !dragSlots.isEmpty else { return }
        let canChange = itemByID(id)?.canChangeStore ?? false
        let above = dragSlots.filter { $0.midY < location.y }
        let rawStore = above.last?.store ?? dragSlots.first?.store ?? dragStartStore
        let store = canChange ? rawStore : dragStartStore
        dragTargetStore = store
        dragTargetIndex = dragSlots.filter { $0.store == store && $0.midY < location.y }.count
    }

    /// Drag released: commit the live target to the data model.
    private func handleStoreDrop(_ id: NSManagedObjectID, _ location: CGPoint) {
        if dragSlots.isEmpty { dragSlots = captureSlots(excluding: id) }
        updateDragTarget(id: id, at: location)
        let target = dragTargetStore ?? dragStartStore
        let index = dragTargetIndex
        let moved = commitDrag(id: id, toStore: target, index: index)
        withAnimation(.spring(duration: 0.3)) { endDrag() }
        if moved > 0 { haptic(.soft) }   // "settle"
        if isUITest { dropDebug = "store:\(target.isEmpty ? "-" : target):i\(index):m\(moved)" }
    }

    /// Move the item to `store` (a catalog item stays in its own store) and
    /// renumber that group so the drag order persists.
    @discardableResult
    private func commitDrag(id: NSManagedObjectID, toStore store: String, index: Int) -> Int {
        guard let item = itemByID(id) else { return 0 }
        let dest = item.canChangeStore ? store : (item.storeName ?? "")
        item.storeName = dest.isEmpty ? nil : dest
        let groupIDs = ShoppingListLogic
            .sorted(Array(items).filter { ($0.storeName ?? "") == dest })
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
        dragSlots = []
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

/// Holds the latest row frames without being observable, so writing them from
/// `onPreferenceChange` never triggers a view update. The drag gesture reads
/// them on demand; `body` never does.
private final class RowFrameStore {
    var rows: [RowFrame] = []
}

/// A fixed drop slot captured at drag start: a store section and a row's
/// vertical midpoint. The finger is hit-tested against these (never the live
/// layout), so the dragged item can slide freely without shifting the target.
private struct DragSlot {
    let store: String
    let midY: CGFloat
}

/// A row to render in a section: a real (interactive) item, or a dimmed preview
/// of the item currently being dragged into this section from another one.
private enum RowSpec: Identifiable {
    case real(CDShoppingItem)
    case preview(CDShoppingItem)
    var id: String {
        switch self {
        case .real(let i): return i.objectID.uriRepresentation().absoluteString
        case .preview(let i): return "preview:" + i.objectID.uriRepresentation().absoluteString
        }
    }
}

/// The live finger position, observed ONLY by the ghost overlay. Kept separate
/// from the List's state so tracking the finger doesn't re-render the List.
private final class DragState: ObservableObject {
    @Published var location: CGPoint = .zero
}

/// The floating ghost. Re-renders on finger movement (it observes `dragState`)
/// without touching the List, and appears/disappears when `item` changes.
private struct DragGhostOverlay: View {
    @ObservedObject var dragState: DragState
    let item: CDShoppingItem?

    var body: some View {
        if let item {
            GeometryReader { geo in
                let origin = geo.frame(in: .global).origin
                DragPreview(item: item)
                    .position(x: dragState.location.x - origin.x,
                              y: dragState.location.y - origin.y)
            }
            .allowsHitTesting(false)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
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
