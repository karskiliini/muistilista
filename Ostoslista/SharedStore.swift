import Foundation
import SwiftData

/// SwiftData store in the shared App Group container so the app and the
/// widget read the same database.
enum SharedStore {
    static let appGroupID = "group.fi.maaranen.ostoslista"

    static func container() throws -> ModelContainer {
        guard let base = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let config = ModelConfiguration(url: base.appendingPathComponent("Ostoslista.sqlite"))
        return try ModelContainer(for: ShoppingItem.self, configurations: config)
    }
}
