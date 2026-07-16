import SwiftUI

struct ShoppingRowView: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    /// Live value while scrubbing; nil when no drag is active.
    @State private var dragQuantity: Int?

    private var isScrubbing: Bool { dragQuantity != nil }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isDone ? Color.green : Color.secondary)
            Text(item.name)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? .secondary : .primary)
            Spacer()
            if item.isDone {
                if item.quantity > 1 {
                    Text("× \(item.quantity)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                quantityHandle
            }
        }
        .animation(.spring(duration: 0.2), value: dragQuantity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }

    /// The drag bar: a pill at the trailing edge. Scrub it left/right to
    /// set the quantity; the rest of the row stays free for other gestures.
    private var quantityHandle: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.left.and.right")
                .font(.caption2.weight(.bold))
            Text("× \(dragQuantity ?? item.quantity)")
                .font(.headline.monospacedDigit())
        }
        .foregroundStyle(isScrubbing ? Color.white
                         : item.quantity > 1 ? Color.secondary : Color.secondary.opacity(0.45))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isScrubbing ? AnyShapeStyle(Color.blue) : AnyShapeStyle(.quinary), in: Capsule())
        .scaleEffect(isScrubbing ? 1.25 : 1.0, anchor: .trailing)
        .contentShape(Rectangle())
        .gesture(quantityDrag)
    }

    private var quantityDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // Mostly-horizontal check on activation keeps list scrolling free.
                if dragQuantity == nil {
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                }
                dragQuantity = ShoppingListLogic.quantity(
                    start: item.quantity,
                    dragWidth: value.translation.width
                )
            }
            .onEnded { _ in
                if let dragQuantity { item.quantity = dragQuantity }
                dragQuantity = nil
            }
    }
}
