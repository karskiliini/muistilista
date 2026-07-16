import SwiftUI

struct ShoppingRowView: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    /// Live value while scrubbing; nil when no drag is active.
    @State private var dragQuantity: Int?

    private var isScrubbing: Bool { dragQuantity != nil }
    private var badgeValue: Int? {
        if let dragQuantity { return dragQuantity }
        return item.quantity > 1 ? item.quantity : nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isDone ? Color.green : Color.secondary)
            Text(item.name)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? .secondary : .primary)
            Spacer()
            if let badgeValue {
                Text("× \(badgeValue)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(isScrubbing ? Color.white : Color.secondary)
                    .padding(.horizontal, isScrubbing ? 12 : 0)
                    .padding(.vertical, isScrubbing ? 5 : 0)
                    .background(isScrubbing ? Color.blue : Color.clear, in: Capsule())
                    .scaleEffect(isScrubbing ? 1.25 : 1.0)
            }
        }
        .animation(.spring(duration: 0.2), value: dragQuantity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .gesture(quantityDrag)
    }

    private var quantityDrag: some Gesture {
        DragGesture(minimumDistance: 25)
            .onChanged { value in
                // Activate only on a drag that starts rightward and mostly
                // horizontal, so swipe-to-delete and scrolling still win.
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
