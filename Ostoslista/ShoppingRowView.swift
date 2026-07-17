import SwiftUI

struct ShoppingRowView: View {
    @ObservedObject var item: CDShoppingItem
    let onToggle: () -> Void

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
        HStack(spacing: 12) {
            // Drag handle: pick the item up and drop it on a store section to
            // move it. Long-press elsewhere still opens the context menu.
            Image(systemName: "line.3.horizontal")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .draggable(item.objectID.uriRepresentation().absoluteString) {
                    Text(item.name)
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("Siirrä vetämällä")
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isDone ? Color.green : Color.secondary)
            // Store items reserve a fixed leading slot so their names align
            // whether or not an image loaded.
            if item.isFromStore {
                thumbnail.frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .lineLimit(2)
                if let subtitle = storeSubtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let price = item.catalogPrice, !price.isEmpty, !isScrubbing {
                Text(price)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if isScrubbing {
                Text("× \(dragQuantity ?? Int(item.quantity))")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.accentColor, in: Capsule())
                    .scaleEffect(1.25, anchor: .trailing)
            } else if item.quantity > 1 {
                Text("× \(item.quantity)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if item.isFromStore {
                Button { showingDetail = true } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.tint)
                        .frame(width: 44, height: 44)
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
        // Discoverable, non-gesture way to change quantity (also covers
        // Switch Control users who can't perform the drag).
        .contextMenu {
            Button { changeQuantity(+1) } label: { Label("Lisää määrää", systemImage: "plus") }
            Button { changeQuantity(-1) } label: { Label("Vähennä määrää", systemImage: "minus") }
                .disabled(item.quantity <= 1)
            Menu {
                ForEach(Stores.groups) { group in
                    Section(group.name) {
                        ForEach(group.stores, id: \.self) { name in
                            Button(name) { moveToStore(name) }
                        }
                    }
                }
                Divider()
                Button("Ei kauppaa") { moveToStore("") }
            } label: {
                Label("Siirrä kauppaan", systemImage: "arrow.left.arrow.right")
            }
            Divider()
            Button(role: .destructive) { deleteSelf() } label: {
                Label("Poista tuote", systemImage: "trash")
            }
        }
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

    private func deleteSelf() {
        let context = item.managedObjectContext
        context?.delete(item)
        try? context?.save()
    }

    /// Reassign the item to another store's group (empty = "Muut").
    private func moveToStore(_ name: String) {
        item.storeName = name.isEmpty ? nil : name
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
