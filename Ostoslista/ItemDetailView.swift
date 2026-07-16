import SwiftUI

/// Details for a store-sourced item: image(s), price, shelf, store,
/// description. Only reachable for catalog-added items; free-text items
/// have nothing extra to show.
struct ItemDetailView: View {
    @ObservedObject var item: CDShoppingItem
    @Environment(\.dismiss) private var dismiss

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
                    LabeledContent("Määrä", value: "\(item.quantity)")
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
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    case .failure: Image(systemName: "photo").foregroundStyle(.quaternary)
                    default: ProgressView()
                    }
                }
                .padding()
            }
        }
        .tabViewStyle(.page)
    }
}
