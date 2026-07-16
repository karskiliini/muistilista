import SwiftUI

/// Details for a store-sourced item: image(s), price, shelf, store,
/// description. Only reachable for catalog-added items; free-text items
/// have nothing extra to show.
struct ItemDetailView: View {
    @ObservedObject var item: CDShoppingItem
    @Environment(\.dismiss) private var dismiss

    private var quantityBinding: Binding<Int> {
        Binding(
            get: { Int(item.quantity) },
            set: { item.quantity = Int64($0); try? item.managedObjectContext?.save() })
    }

    var body: some View {
        NavigationStack {
            List {
                if !item.imageURLs.isEmpty {
                    Section {
                        imageStrip
                            .listRowInsets(EdgeInsets())
                            .frame(height: 240)
                    }
                }
                Section {
                    if let price = item.catalogPrice, !price.isEmpty {
                        LabeledContent("Hinta", value: price)
                    }
                    if let store = item.storeName, !store.isEmpty {
                        LabeledContent("Kauppa", value: store)
                    }
                    if let shelf = item.shelfLocation, !shelf.isEmpty {
                        LabeledContent("Hyllypaikka", value: shelf)
                    }
                    Stepper("Määrä: \(item.quantity)", value: quantityBinding, in: 1...99)
                }
                if let desc = item.productDescription, !desc.isEmpty {
                    Section("Kuvaus") { Text(desc) }
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valmis") { dismiss() }
                }
            }
        }
    }

    private var imageStrip: some View {
        TabView {
            ForEach(item.imageURLs, id: \.self) { url in
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .padding()
            }
        }
        .tabViewStyle(.page)
    }
}
