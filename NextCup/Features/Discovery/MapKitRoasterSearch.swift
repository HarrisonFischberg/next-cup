import CoreLocation
import Foundation
import MapKit

/// The only outbound call S10 makes (blueprint §3b): an Apple `MKLocalSearch`
/// for "coffee roaster", around a point or in a typed city. No key, no backend.
struct MapKitRoasterSearch: RoasterSearching {
  private static let radiusMeters: CLLocationDistance = 25_000

  func search(_ area: SearchArea) async throws -> [RoasterPlace] {
    let places = try await search(area, request: Self.request(for: area))
    // A bag's brand ("… Coffee Roasters") plus "coffee roaster" often finds nothing;
    // the brand alone usually finds the business.
    if places.isEmpty, case .named(let name) = area {
      let plain = MKLocalSearch.Request()
      plain.naturalLanguageQuery = name
      plain.resultTypes = .pointOfInterest
      return try await search(area, request: plain)
    }
    return places
  }

  private static func request(for area: SearchArea) -> MKLocalSearch.Request {
    let request = MKLocalSearch.Request()
    switch area {
    case .near(let latitude, let longitude):
      request.naturalLanguageQuery = "coffee roaster"
      request.region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
        latitudinalMeters: Self.radiusMeters, longitudinalMeters: Self.radiusMeters)
    case .city(let city):
      request.naturalLanguageQuery = "coffee roaster in \(city)"
    case .named(let name):
      request.naturalLanguageQuery = "\(name) coffee roaster"
    }
    request.resultTypes = .pointOfInterest
    return request
  }

  private func search(_ area: SearchArea, request: MKLocalSearch.Request) async throws
    -> [RoasterPlace]
  {
    let response: MKLocalSearch.Response
    do {
      response = try await MKLocalSearch(request: request).start()
    } catch let error as MKError where error.code == .placemarkNotFound {
      return []  // Apple Maps reports "nothing found" as an error, not an empty list.
    }
    var seen = Set<String>()
    return response.mapItems.compactMap { item in
      guard let name = item.name, !name.isEmpty else { return nil }
      let coordinate = item.location.coordinate
      let place = RoasterPlace(
        name: name, city: item.addressRepresentations?.cityName, website: item.url,
        latitude: coordinate.latitude, longitude: coordinate.longitude,
        address: item.address?.fullAddress, phone: item.phoneNumber,
        mapItemID: item.identifier?.rawValue)
      return seen.insert(place.id).inserted ? place : nil
    }
  }
}

/// Asks for location when in use, takes the first fix and lets go. The point is
/// used for one search and never stored.
@MainActor
struct DeviceLocation: LocationProviding {
  var isAuthorized: Bool {
    let status = CLLocationManager().authorizationStatus
    return status == .authorizedWhenInUse || status == .authorizedAlways
  }

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
  /// location tap take the denied path, and `-locationStub authorized` is a user
  /// who already allowed location.
  struct StubRoasterSearch: RoasterSearching {
    func search(_ area: SearchArea) async throws -> [RoasterPlace] {
      switch area {
      case .city(let text), .named(let text):
        if text.lowercased() == "nowhere" { return [] }
        if text.lowercased() == "offline" { throw URLError(.notConnectedToInternet) }
      case .near:
        break
      }
      return [
        RoasterPlace(
          name: "Sample Roasters One", city: "Sampletown",
          website: URL(string: "https://sample-roasters.example"), latitude: 45.52,
          longitude: -122.68, address: "12 Sample Street\nSampletown, OR 97200",
          phone: "+1 (503) 555-0100"),
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
    var isAuthorized = false
    func currentLocation() async -> LocationOutcome { outcome }
  }
#endif

/// The real MapKit search, or the stub when a UI test passes `-roasterStub`.
func liveRoasterSearcher() -> RoasterSearching {
  #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("-roasterStub") { return StubRoasterSearch() }
  #endif
  return MapKitRoasterSearch()
}

extension RoasterDiscoveryModel {
  /// The real search and location, or the stubs when a UI test asks for them.
  static func live() -> RoasterDiscoveryModel {
    #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      if arguments.contains("-roasterStub") {
        let stub = arguments.firstIndex(of: "-locationStub").map { $0 + 1 }
          .flatMap { arguments.indices.contains($0) ? arguments[$0] : nil }
        return RoasterDiscoveryModel(
          searcher: StubRoasterSearch(),
          location: StubLocation(
            outcome: stub == "denied" ? .denied : .granted(latitude: 45.52, longitude: -122.68),
            isAuthorized: stub == "authorized"))
      }
    #endif
    return RoasterDiscoveryModel(searcher: MapKitRoasterSearch(), location: DeviceLocation())
  }
}
