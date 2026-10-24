import CoreLocation
import Foundation
import MapKit

/// The only outbound call S10 makes (blueprint §3b): an Apple `MKLocalSearch`
/// for "coffee roaster", around a point or in a typed city. No key, no backend.
struct MapKitRoasterSearch: RoasterSearching {
  private static let radiusMeters: CLLocationDistance = 25_000

  func search(_ area: SearchArea) async throws -> [RoasterPlace] {
    let request = MKLocalSearch.Request()
    switch area {
    case .near(let latitude, let longitude):
      request.naturalLanguageQuery = "coffee roaster"
      request.region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
        latitudinalMeters: Self.radiusMeters, longitudinalMeters: Self.radiusMeters)
    case .city(let city):
      request.naturalLanguageQuery = "coffee roaster in \(city)"
    }
    request.resultTypes = .pointOfInterest
    let response = try await MKLocalSearch(request: request).start()
    var seen = Set<String>()
    return response.mapItems.compactMap { item in
      guard let name = item.name, !name.isEmpty else { return nil }
      let coordinate = item.location.coordinate
      let place = RoasterPlace(
        name: name, city: item.addressRepresentations?.cityName, website: item.url,
        latitude: coordinate.latitude, longitude: coordinate.longitude)
      return seen.insert(place.id).inserted ? place : nil
    }
  }
}

/// Asks for location when in use, takes the first fix and lets go. The point is
/// used for one search and never stored.
@MainActor
struct DeviceLocation: LocationProviding {
  func currentLocation() async -> LocationOutcome {
    let session = CLServiceSession(authorization: .whenInUse)
    defer { session.invalidate() }
    do {
      for try await update in CLLocationUpdate.liveUpdates() {
        if update.authorizationDenied || update.authorizationDeniedGlobally
          || update.authorizationRestricted
        {
          return .denied
        }
        if let location = update.location {
          return .granted(
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
      }
    } catch {
      return .unavailable
    }
    return .unavailable
  }
}

#if DEBUG
  /// Synthetic roasters for UI tests, chosen with `-roasterStub`. The city
  /// "Nowhere" finds none and "Offline" fails, so every state can be reached
  /// without a network or a location prompt. `-locationStub denied` makes the
  /// location tap take the denied path.
  struct StubRoasterSearch: RoasterSearching {
    func search(_ area: SearchArea) async throws -> [RoasterPlace] {
      if case .city(let city) = area {
        if city.lowercased() == "nowhere" { return [] }
        if city.lowercased() == "offline" { throw URLError(.notConnectedToInternet) }
      }
      return [
        RoasterPlace(
          name: "Sample Roasters One", city: "Sampletown", website: nil, latitude: 45.52,
          longitude: -122.68),
        RoasterPlace(
          name: "Sample Roasters Two", city: "Sampletown", website: nil, latitude: 45.53,
          longitude: -122.66),
        RoasterPlace(
          name: "Sample Roasters Three", city: "Sampletown", website: nil, latitude: 45.51,
          longitude: -122.64),
      ]
    }
  }

  struct StubLocation: LocationProviding {
    let outcome: LocationOutcome
    func currentLocation() async -> LocationOutcome { outcome }
  }
#endif

extension RoasterDiscoveryModel {
  /// The real search and location, or the stubs when a UI test asks for them.
  static func live() -> RoasterDiscoveryModel {
    #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      if arguments.contains("-roasterStub") {
        let denied =
          arguments.firstIndex(of: "-locationStub").map { $0 + 1 }
          .flatMap { arguments.indices.contains($0) ? arguments[$0] : nil } == "denied"
        return RoasterDiscoveryModel(
          searcher: StubRoasterSearch(),
          location: StubLocation(
            outcome: denied ? .denied : .granted(latitude: 45.52, longitude: -122.68)))
      }
    #endif
    return RoasterDiscoveryModel(searcher: MapKitRoasterSearch(), location: DeviceLocation())
  }
}
