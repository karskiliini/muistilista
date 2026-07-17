import SwiftUI

/// Detail of a catalog search result (before it's on the list): image(s),
/// price, brand, shelf/category and description, with a prominent add
/// button. Pushed from the store search; adding closes the whole store
/// view and drops the item onto the list.
struct CatalogProductDetailView: View {
    let product: CatalogProduct
    let storeName: String
    let onAdd: () -> Void

    @ObservedObject private var motonet = MotonetWebEngine.shared
    @State private var motonetShelf: String?
    @State private var loadingShelf = false
    @State private var showStoreSheet = false

    init(product: CatalogProduct, storeName: String = "", onAdd: @escaping () -> Void) {
        self.product = product
        self.storeName = storeName
        self.onAdd = onAdd
    }

    private var isMotonet: Bool { MotonetCatalog.handles(storeName: storeName) }

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
                shelfRow
                if product.shelfLocation == nil, !isMotonet,
                   let hint = ShoppingListLogic.categoryHint(product.categoryPath) {
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
                Button(action: onAdd) { Label("Lisää listalle", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showStoreSheet) { MotonetStoreSheet() }
        .task(id: motonet.storeName) { await loadMotonetShelfIfNeeded() }
    }

    /// Shows the shelf from the catalog if present, otherwise (for Motonet)
    /// the shelf fetched via the store's web page, or a store-picker prompt.
    @ViewBuilder private var shelfRow: some View {
        if let shelf = product.shelfLocation, !shelf.isEmpty {
            LabeledContent("Hyllypaikka", value: shelf)
        } else if isMotonet {
            if let motonetShelf {
                LabeledContent("Hyllypaikka", value: motonetShelf)
            } else if loadingShelf {
                HStack { Text("Hyllypaikka"); Spacer(); ProgressView() }
            } else if !motonet.hasStore {
                Button {
                    showStoreSheet = true
                } label: {
                    Label("Valitse tavaratalo nähdäksesi hyllypaikan", systemImage: "mappin.and.ellipse")
                }
            }
        }
    }

    private func loadMotonetShelfIfNeeded() async {
        guard isMotonet, product.shelfLocation == nil, motonet.hasStore, motonetShelf == nil else { return }
        loadingShelf = true
        motonetShelf = await motonet.shelf(forProductCode: product.id)
        loadingShelf = false
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
