import CoreLocation

/// First-use automatic store choice (R36): device location → city name →
/// that city's stores of the chain → geocode their addresses → closest.
/// Every step degrades to nil; the caller then falls back to the manual
/// picker sheet. Fills only a void: never overwrites a selection that
/// already exists (checked on entry, and again just before persisting) so
/// a straggling auto-select can't clobber a manual pick made while it was
/// still resolving.
enum NearestStore {
    /// Pure distance pick over pre-resolved coordinates (unit-tested).
    static func nearest(of candidates: [(StoreLocation, CLLocationCoordinate2D?)],
                        to user: CLLocationCoordinate2D) -> StoreLocation? {
        let here = CLLocation(latitude: user.latitude, longitude: user.longitude)
        return candidates
            .compactMap { store, coord -> (StoreLocation, CLLocationDistance)? in
                guard let coord else { return nil }
                let there = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                return (store, here.distance(from: there))
            }
            .min { $0.1 < $1.1 }?.0
    }

    /// Full flow. Returns the chosen (and already persisted) store, or nil
    /// when any step fails (no permission, no geocode, no stores).
    static func autoSelect(chain: String) async -> StoreLocation? {
        guard let brand = SKaupatStoreDirectory.chainBrands[chain] else { return nil }
        // Someone already chose (manually, or an earlier auto-select) —
        // never second-guess that, and skip CoreLocation entirely.
        if let existing = SelectedStores.selection(for: chain) { return existing }
        guard let coordinate = try? await LocationOnce.current() else { return nil }
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let city = (try? await geocoder.reverseGeocodeLocation(location))?
                .first?.locality else { return nil }
        guard let stores = try? await SKaupatStoreDirectory()
                .searchStores(query: city, brand: brand), !stores.isEmpty else { return nil }
        var pairs: [(StoreLocation, CLLocationCoordinate2D?)] = []
        for store in stores.prefix(10) {
            let address = "\(store.street), \(store.city), Finland"
            let coord = (try? await geocoder.geocodeAddressString(address))?
                .first?.location?.coordinate
            pairs.append((store, coord))
        }
        // If no address geocoded, a lone city hit is still a sane default.
        let chosen = nearest(of: pairs, to: coordinate) ?? (stores.count == 1 ? stores[0] : nil)
        // A manual pick (or another auto-select) may have landed while this
        // one was resolving — that selection wins, ours is discarded.
        if let existing = SelectedStores.selection(for: chain) { return existing }
        if let chosen { SelectedStores.select(chosen, for: chain) }
        return chosen
    }
}
