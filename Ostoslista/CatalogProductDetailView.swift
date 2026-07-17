import SwiftUI

/// Detail of a catalog search result (before it's on the list): image(s),
/// price, brand, shelf/category and description, with a prominent add
/// button. Pushed from the store search; adding closes the whole store
/// view and drops the item onto the list.
struct CatalogProductDetailView: View {
    let product: CatalogProduct
    let onAdd: () -> Void

    var body: some View {
        List {
            if !product.imageURLs.isEmpty {
                Section {
                    imageStrip
                        .listRowInsets(EdgeInsets())
                        .frame(height: 260)
                }
            }
            Section {
                if let price = product.priceText {
                    LabeledContent("Hinta", value: price)
                }
                if let comparison = product.comparison {
                    LabeledContent("Vertailuhinta", value: comparison)
                }
                if let brand = product.brand, !brand.isEmpty {
                    LabeledContent("Merkki", value: brand)
                }
                if let shelf = product.shelfLocation, !shelf.isEmpty {
                    LabeledContent("Hyllypaikka", value: shelf)
                } else if let hint = ShoppingListLogic.categoryHint(product.categoryPath) {
                    LabeledContent("Kategoria", value: hint)
                }
            }
            if let desc = product.description, !desc.isEmpty {
                Section("Kuvaus") { Text(desc) }
            }
            Section {
                Button(action: onAdd) {
                    Label("Lisää listalle", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAdd) {
                    Label("Lisää listalle", systemImage: "plus")
                }
            }
        }
    }

    private var imageStrip: some View {
        TabView {
            ForEach(product.imageURLs, id: \.self) { url in
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
