import Foundation

/// Remembered store choice per chain ("S-market" → S-market Kommila
/// Varkaus). Device-local by design (spec: ei perhesynkkaa). Lives in the
/// App Group so a future widget/extension could read it too.
enum SelectedStores {
    static var defaults: UserDefaults =
        UserDefaults(suiteName: CoreDataStack.appGroupID) ?? .standard

    private static func key(_ chain: String) -> String { "storeLocation.\(chain)" }

    static func selection(for chain: String) -> StoreLocation? {
        guard let data = defaults.data(forKey: key(chain)) else { return nil }
        return try? JSONDecoder().decode(StoreLocation.self, from: data)
    }

    static func select(_ store: StoreLocation?, for chain: String) {
        if let store, let data = try? JSONEncoder().encode(store) {
            defaults.set(data, forKey: key(chain))
        } else {
            defaults.removeObject(forKey: key(chain))
        }
    }
}
