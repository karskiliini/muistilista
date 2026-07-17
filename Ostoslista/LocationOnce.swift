import CoreLocation

/// One-shot location fetch: requests when-in-use permission and returns a
/// single coordinate. Used to pick the nearest K-ruoka store. Kept tiny and
/// self-contained; failure just means no location-based store selection.
final class LocationOnce: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private static var live: LocationOnce?   // keep alive during the async request

    static func current() async throws -> CLLocationCoordinate2D {
        let helper = LocationOnce()
        live = helper
        defer { live = nil }
        return try await helper.request()
    }

    private func request() async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { cont in
            continuation = cont
            manager.delegate = self
            manager.requestWhenInUseAuthorization()
            manager.requestLocation()
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.first?.coordinate else { return }
        continuation?.resume(returning: coord); continuation = nil
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error); continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        if m.authorizationStatus == .denied || m.authorizationStatus == .restricted {
            continuation?.resume(throwing: CLError(.denied)); continuation = nil
        }
    }
}
