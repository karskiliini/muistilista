import Foundation

/// The fixed set of stores the user can pick from. Users cannot add their
/// own — the list is curated so each entry can (eventually) map to a
/// catalog provider. Grouped for the dropdown.
enum Stores {
    struct Group: Identifiable {
        let name: String
        let stores: [String]
        var id: String { name }
    }

    static let groups: [Group] = [
        Group(name: "S-ryhmä", stores: [
            "Prisma", "S-market", "Sale", "Alepa", "ABC",
        ]),
        Group(name: "K-ryhmä", stores: [
            "K-Citymarket", "K-Supermarket", "K-Market", "K-Rauta",
        ]),
        Group(name: "Muut", stores: [
            "Lidl", "Tokmanni", "Puuilo", "Motonet", "Gigantti",
        ]),
    ]

    static let all: [String] = groups.flatMap(\.stores)
}
