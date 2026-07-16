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
            if isScrubbing {
                Text("× \(dragQuantity ?? item.quantity)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.blue, in: Capsule())
                    .scaleEffect(1.25, anchor: .trailing)
            } else if item.quantity > 1 {
                Text("× \(item.quantity)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            // Hint: this edge pulls left to delete (system swipe action).
            Image(systemName: "chevron.compact.left")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .animation(.spring(duration: 0.2), value: dragQuantity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .simultaneousGesture(quantityDrag)
    }

    private var quantityDrag: some Gesture {
        DragGesture(minimumDistance: 25)
            .onChanged { value in
                // Checked items keep their final quantity — no scrubbing.
                guard !item.isDone else { return }
                // Activate only on a drag that starts rightward and mostly
                // horizontal; leftward drags belong to swipe-to-delete and
                // vertical ones to scrolling.
                if dragQuantity == nil {
                    guard value.translation.width > 0,
                          abs(value.translation.width) > abs(value.translation.height)
                    else { return }
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
