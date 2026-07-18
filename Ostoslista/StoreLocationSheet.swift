// Ostoslista/StoreLocationSheet.swift
import SwiftUI

/// Manual store picker (R36): search s-kaupat store directory by name or
/// town, tap to select. Also the fallback when auto-selection fails.
struct StoreLocationSheet: View {
    let chain: String
    let onSelected: (StoreLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [StoreLocation] = []
    @State private var searching = false
    @State private var errorText: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hae myymälää…", text: $query)
                        .accessibilityIdentifier("store-location-search")
                        .onChange(of: query) { _, _ in runSearch() }
                } footer: {
                    Text("Hae myymälän nimellä tai paikkakunnalla (esim. \"kommila\" tai \"Varkaus\").")
                }
                Section {
                    if let errorText {
                        Text(errorText).foregroundStyle(.secondary)
                    } else if searching {
                        HStack { ProgressView(); Text("Haetaan…").foregroundStyle(.secondary) }
                    } else {
                        ForEach(results) { store in
                            Button {
                                SelectedStores.select(store, for: chain)
                                onSelected(store)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.name).foregroundStyle(.primary)
                                    Text("\(store.street), \(store.city)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        if results.isEmpty, ShoppingListLogic.normalized(query) != nil {
                            Text("Ei osumia").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Valitse myymälä")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Peruuta") { dismiss() }
                }
            }
        }
    }

    private func runSearch() {
        searchTask?.cancel()
        errorText = nil
        guard let q = ShoppingListLogic.normalized(query) else {
            results = []; searching = false; return
        }
        searching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            do {
                let found = try await StoreDirectory.search(
                    query: q, brand: SKaupatStoreDirectory.chainBrands[chain])
                if Task.isCancelled { return }
                await MainActor.run { results = found; searching = false }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    errorText = "Myymälöitä ei saatu haettua — yritä uudelleen"
                    searching = false
                }
            }
        }
    }
}
