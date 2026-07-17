import SwiftUI
import CoreData

struct ShoppingRowView: View {
    @ObservedObject var item: CDShoppingItem
    let onToggle: () -> Void
    /// Store drag callbacks — locations are in the List's "list" coordinate
    /// space so the parent can hit-test them against store sections.
    var onStoreDrag: ((NSManagedObjectID, CGPoint) -> Void)? = nil
    var onStoreDrop: ((NSManagedObjectID, CGPoint) -> Void)? = nil

    /// Live value while scrubbing; nil when no drag is active.
    @State private var dragQuantity: Int?
    @State private var showingDetail = false

    private var isScrubbing: Bool { dragQuantity != nil }

    /// "K-CM Kuopio · käytävä 12" — only for items added via a store.
    private var storeSubtitle: String? {
        let parts = [item.storeName, item.shelfLocation].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 4) {
            // Slim drag handle on EVERY row: free-text items can be reordered
            // and moved between stores, catalog items can be reordered within
            // their own store (they just can't leave it — enforced by the
            // parent). A narrow grip keeps rows compact; the tap area stays
            // tall enough to grab and win the drag over the List's scrolling.
            Image(systemName: "line.3.horizontal")
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .frame(width: 18, height: 40)
                .contentShape(Rectangle())
                .highPriorityGesture(storeDrag)
                .accessibilityLabel("Siirrä vetämällä")
                .accessibilityIdentifier("handle-\(item.name)")
            rowContent
        }
    }

    /// Custom store-move drag. Unlike `.draggable`/`.dropDestination` (which
    /// never engaged inside this List), a plain DragGesture responds to raw
    /// touch-move events, so it works on-device AND under simulated UI-test
    /// gestures. Locations resolve in `.global` (screen) space — the one space
    /// that a List cell's gesture and the rows' frame readers agree on — so the
    /// parent can map the finger onto a store section.
    private var storeDrag: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { onStoreDrag?(item.objectID, $0.location) }
            .onEnded { onStoreDrop?(item.objectID, $0.location) }
    }

    /// One compact line under the name: store/shelf and price. Keeping the
    /// price here (not trailing) keeps rows narrow and short so many fit.
    private var detailLine: String? {
        let price = (item.catalogPrice ?? "").isEmpty ? nil : item.catalogPrice
        let parts = [storeSubtitle, price].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(item.isDone ? Color.green : Color.secondary)
            // Only real catalog images get a thumbnail — no empty placeholder
            // boxes for plain store-assigned items.
            if !item.imageURLs.isEmpty {
                thumbnail.frame(width: 26, height: 26)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.subheadline)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .lineLimit(1)
                if let detail = detailLine {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("store-\(item.name)")
                }
            }
            Spacer(minLength: 6)
            if isScrubbing {
                Text("× \(dragQuantity ?? Int(item.quantity))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.accentColor, in: Capsule())
                    .scaleEffect(1.2, anchor: .trailing)
            } else if item.quantity > 1 {
                Text("× \(item.quantity)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if item.hasCatalogDetail {
                Button { showingDetail = true } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.tint)
                        .frame(width: 32, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Tuotetiedot")
            }
        }
        .animation(.spring(duration: 0.2), value: dragQuantity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .simultaneousGesture(quantityDrag)
        .sheet(isPresented: $showingDetail) { ItemDetailView(item: item) }
        // VoiceOver: swipe up/down adjusts quantity.
        .accessibilityValue(item.quantity > 1 ? "\(item.quantity) kappaletta" : "")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: changeQuantity(+1)
            case .decrement: changeQuantity(-1)
            @unknown default: break
            }
        }
    }

    private var thumbnail: some View {
        Group {
            if let url = item.imageURLs.first {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Image(systemName: "photo").font(.caption).foregroundStyle(.quaternary)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "bag").font(.caption).foregroundStyle(.quaternary)
            }
        }
    }

    private func changeQuantity(_ delta: Int) {
        item.quantity = Int64(max(1, Int(item.quantity) + delta))
        try? item.managedObjectContext?.save()
    }

    private var quantityDrag: some Gesture {
        DragGesture(minimumDistance: 25)
            .onChanged { value in
                // Checked items keep their final quantity — no scrubbing.
                guard !item.isDone else { return }
                // Activate on any mostly-horizontal drag — rightward raises
                // the quantity, leftward lowers it immediately. (Vertical
                // drags are left to scrolling.)
                if dragQuantity == nil {
                    guard abs(value.translation.width) > abs(value.translation.height),
                          abs(value.translation.width) > 4
                    else { return }
                }
                dragQuantity = ShoppingListLogic.quantity(
                    start: Int(item.quantity),
                    dragWidth: value.translation.width
                )
            }
            .onEnded { _ in
                if let dragQuantity {
                    item.quantity = Int64(dragQuantity)
                    try? item.managedObjectContext?.save()
                }
                dragQuantity = nil
            }
    }
}
