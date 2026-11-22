import CoreLocation
import Foundation
import MapKit
import SwiftData

/// One roaster found on the map. Nothing is stored until the user saves it.
struct RoasterPlace: Identifiable, Hashable, Sendable {
  let name: String
  let city: String?
  let website: URL?
  let latitude: Double
  let longitude: Double
  var address: String?
  var phone: String?
  /// Apple Maps' identifier for the place, used to open its place card (hours, photos).
  var mapItemID: String?

  var id: String { "\(name)|\(Int(latitude * 10_000))|\(Int(longitude * 10_000))" }
}

extension RoasterPlace {
  /// A saved roaster as a place, when it was saved with its spot on the map.
  init?(_ roaster: Roaster) {
    guard let latitude = roaster.latitude, let longitude = roaster.longitude else { return nil }
    self.init(
      name: roaster.name, city: roaster.city, website: roaster.website, latitude: latitude,
      longitude: longitude)
  }

  /// `tel:` link for the phone number, or nil when there is no dialable number.
  var callURL: URL? {
    guard let phone else { return nil }
    let digits = phone.filter { $0.isNumber || $0 == "+" }
    return digits.count >= 3 ? URL(string: "tel:\(digits)") : nil
  }

  /// Driving directions to the roaster in Apple Maps.
  var directionsURL: URL? {
    var parts = URLComponents(string: "https://maps.apple.com/")
    parts?.queryItems = [
      URLQueryItem(name: "daddr", value: "\(latitude),\(longitude)"),
      URLQueryItem(name: "q", value: name),
    ]
    return parts?.url
  }

  /// The roaster in Google Maps (the app when installed, else the browser). Only the
  /// roaster's name and address go in the link, never the user's location.
  var googleMapsURL: URL? {
    var parts = URLComponents(string: "https://www.google.com/maps/search/")
    let place = [name, address?.replacingOccurrences(of: "\n", with: ", ") ?? city]
      .compactMap { $0 }.joined(separator: ", ")
    parts?.queryItems = [
      URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: place),
    ]
    return parts?.url
  }
}

/// A point on the map.
struct MapPoint: Equatable, Sendable {
  let latitude: Double
  let longitude: Double

  func distance(to other: MapPoint) -> Double {
    CLLocation(latitude: latitude, longitude: longitude)
      .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
  }
}

extension RoasterPlace {
  var point: MapPoint { MapPoint(latitude: latitude, longitude: longitude) }
}

/// Words for how far a roaster is, in the units of the user's region.
enum RoasterDistance {
  static func text(meters: Double, precise: Bool, locale: Locale = .current) -> String {
    let distance = Measurement(
      value: precise ? meters : max(meters, 1_000), unit: UnitLength.meters)
    if precise {
      return distance.formatted(.measurement(width: .abbreviated, usage: .road).locale(locale))
    }
    // Approximate location can be a few kilometres off, so no decimals and an "about".
    let rounded = distance.formatted(
      .measurement(
        width: .abbreviated, usage: .road,
        numberFormatStyle: .number.precision(.fractionLength(0))
      ).locale(locale))
    return "About \(rounded)"
  }
}

/// The map's framing: a region that shows every result, and whether the user has
/// moved far enough from it to offer "Search this area".
enum RoasterMap {
  static func region(fitting places: [RoasterPlace], around origin: MapPoint? = nil)
    -> MKCoordinateRegion?
  {
    let points = places.map(\.point) + (origin.map { [$0] } ?? [])
    guard let first = points.first else { return nil }
    var (minLat, maxLat, minLon, maxLon) =
      (first.latitude, first.latitude, first.longitude, first.longitude)
    for point in points {
      minLat = min(minLat, point.latitude)
      maxLat = max(maxLat, point.latitude)
      minLon = min(minLon, point.longitude)
      maxLon = max(maxLon, point.longitude)
    }
    return MKCoordinateRegion(
      center: CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
      span: MKCoordinateSpan(
        // Pins are drawn above their point, so there is more room top to bottom.
        latitudeDelta: max((maxLat - minLat) * 1.9, 0.02),
        longitudeDelta: max((maxLon - minLon) * 1.4, 0.02)))
  }

  static func moved(from shown: MKCoordinateRegion, to now: MKCoordinateRegion) -> Bool {
    let shift = max(
      abs(now.center.latitude - shown.center.latitude) / shown.span.latitudeDelta,
      abs(now.center.longitude - shown.center.longitude) / shown.span.longitudeDelta)
    let zoom = now.span.latitudeDelta / shown.span.latitudeDelta
    return shift > 0.25 || zoom < 0.6 || zoom > 1.6
  }
}

/// Where to look: around the device (used for the search, never stored) or a
/// city the user typed.
enum SearchArea: Equatable, Sendable {
  case near(latitude: Double, longitude: Double)
  case city(String)
  /// A roaster name read off a bag, looked up to match a real business (T031).
  case named(String)
  /// The part of the map on screen ("Search this area").
  case region(
    latitude: Double, longitude: Double, latitudeDelta: Double, longitudeDelta: Double)
}

enum LocationOutcome: Equatable, Sendable {
  case granted(latitude: Double, longitude: Double)
  case denied
  case unavailable
}

protocol RoasterSearching: Sendable {
  func search(_ area: SearchArea) async throws -> [RoasterPlace]
}

@MainActor
protocol LocationProviding {
  /// True once the user has allowed location (While Using or Always).
  var isAuthorized: Bool { get }
  /// True when the user turned on Precise Location. Next Cup asks for approximate
  /// location, so distances are rounded and say "about" unless this is on.
  var isPrecise: Bool { get }
  func currentLocation() async -> LocationOutcome
}

extension LocationProviding {
  var isPrecise: Bool { false }
}

/// S10: finds roasters near the user or in a typed city. Location is asked for
/// only when the user taps "Use my location"; once it is allowed, opening the
/// screen searches around the user straight away. When it is denied or unavailable
/// the typed city still works, so nothing on this screen needs location.
@MainActor
@Observable
final class RoasterDiscoveryModel {
  enum Phase: Equatable {
    case idle, locating, searching, results
    case failed(String)
  }

  private(set) var phase = Phase.idle
  private(set) var places: [RoasterPlace] = []
  private(set) var locationNotice: String?
  /// Said under the map when "Search this area" finds nothing there.
  private(set) var areaNotice: String?
  /// Where the user is, from the last "near me" search. Held in memory for distances
  /// while the screen is open, never stored.
  private(set) var origin: MapPoint?
  var city = ""

  private let searcher: RoasterSearching
  private let location: LocationProviding
  private var lastArea: SearchArea?

  init(searcher: RoasterSearching, location: LocationProviding) {
    self.searcher = searcher
    self.location = location
  }

  var isBusy: Bool { phase == .locating || phase == .searching }

  /// Location already allowed: the screen opens on the map, with no ask and no hint.
  var opensOnMap: Bool { location.isAuthorized }

  /// Called when the screen opens. With location already allowed it goes straight
  /// to the roasters nearby; otherwise it waits for the user.
  func start() async {
    guard phase == .idle, places.isEmpty, location.isAuthorized else { return }
    await useMyLocation()
  }

  func useMyLocation() async {
    guard !isBusy else { return }
    phase = .locating
    locationNotice = nil
    switch await location.currentLocation() {
    case .granted(let latitude, let longitude):
      await run(.near(latitude: latitude, longitude: longitude))
    case .denied:
      phase = .idle
      locationNotice =
        "Location is off for Next Cup. Type a city to search, or allow location in Settings."
    case .unavailable:
      phase = .idle
      locationNotice = "Your location is not available right now. Type a city to search."
    }
  }

  func searchCity() async {
    let typed = city.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !isBusy, !typed.isEmpty else { return }
    locationNotice = nil
    await run(.city(typed))
  }

  /// "Search this area": roasters in the part of the map on screen. The results
  /// replace the list; finding none keeps the list and says so.
  func searchRegion(_ region: MKCoordinateRegion) async {
    guard !isBusy else { return }
    await run(
      .region(
        latitude: region.center.latitude, longitude: region.center.longitude,
        latitudeDelta: region.span.latitudeDelta, longitudeDelta: region.span.longitudeDelta))
  }

  /// True while the list shows the result of "Search this area", so the map stays put.
  var showsRegionResults: Bool {
    if case .region = lastArea { return true }
    return false
  }

  /// "0.8 mi" from the user, or "About 2 mi" with approximate location. Nil when the
  /// search was not around the user.
  func distanceText(to place: RoasterPlace) -> String? {
    origin.map {
      RoasterDistance.text(meters: $0.distance(to: place.point), precise: location.isPrecise)
    }
  }

  func retry() async {
    guard !isBusy, let lastArea else { return }
    await run(lastArea)
  }

  private func run(_ area: SearchArea) async {
    let previous = (area: lastArea, places: places)
    lastArea = area
    areaNotice = nil
    switch area {
    case .near(let latitude, let longitude):
      origin = MapPoint(latitude: latitude, longitude: longitude)
    case .city, .named: origin = nil
    case .region: break  // still measured from where the user is
    }
    phase = .searching
    do {
      var found = try await searcher.search(area)
      if let origin {
        found.sort { origin.distance(to: $0.point) < origin.distance(to: $1.point) }
      }
      if found.isEmpty, case .region = area, !previous.places.isEmpty {
        lastArea = previous.area
        areaNotice = "No roasters in this part of the map. Move the map and search again."
      } else {
        places = found
      }
      phase = .results
    } catch is CancellationError {
      phase = .idle
    } catch {
      places = []
      phase = .failed(RoasterSearchFailure.message(for: error))
    }
  }
}

/// T031: looks up the roaster name from a bag. Searching stores nothing; the
/// caller applies a place only when the user picks one.
@MainActor
@Observable
final class RoasterMatchModel {
  enum Phase: Equatable {
    case searching, results
    case failed(String)
  }

  private(set) var phase = Phase.searching
  private(set) var places: [RoasterPlace] = []
  private(set) var isOffline = false
  let name: String
  private let searcher: RoasterSearching

  init(name: String, searcher: RoasterSearching) {
    self.name = name
    self.searcher = searcher
  }

  func search() async {
    phase = .searching
    isOffline = false
    do {
      places = try await searcher.search(.named(name))
      phase = .results
    } catch is CancellationError {
      phase = .results
    } catch {
      places = []
      isOffline = RoasterSearchFailure.isOffline(error)
      phase = .failed(RoasterSearchFailure.message(for: error))
    }
  }
}

/// Saves and removes roasters from the map. Only a roaster the user saves is
/// written; search results alone never touch the store.
@MainActor
struct RoasterService {
  let store: Store

  /// Saves the place, reusing a roaster of the same name (any case) that a bean
  /// already points at, so saving never splits one roaster in two.
  @discardableResult
  func save(_ place: RoasterPlace) -> Result<Roaster, StoreError> {
    do {
      let existing = try store.context.fetch(FetchDescriptor<Roaster>()).first {
        $0.name.compare(place.name, options: [.caseInsensitive, .diacriticInsensitive])
          == .orderedSame
      }
      let roaster = try store.upsert(
        Roaster.self, id: existing?.id ?? UUID(), make: { Roaster(name: place.name) },
        update: {
          $0.city = place.city ?? $0.city
          $0.website = place.website ?? $0.website
          $0.latitude = place.latitude
          $0.longitude = place.longitude
          $0.savedFromMap = true
        })
      return commit { roaster }
    } catch {
      store.context.rollback()
      return .failure(.saveFailed(error.localizedDescription))
    }
  }

  /// Takes the roaster off the saved list. One that beans still point at stays
  /// as a plain roaster, so no bean loses its roaster.
  func unsave(_ roaster: Roaster) -> Result<Void, StoreError> {
    if roaster.beans?.isEmpty ?? true {
      store.context.delete(roaster)
    } else {
      roaster.savedFromMap = false
      roaster.updatedAt = Date()
    }
    return commit { () }
  }

  /// Saves the place, or takes it off the saved list when it is already there.
  func toggle(_ place: RoasterPlace, in saved: [Roaster]) -> Result<Void, StoreError> {
    let existing = saved.first {
      $0.name.compare(place.name, options: [.caseInsensitive, .diacriticInsensitive])
        == .orderedSame
    }
    if let existing { return unsave(existing) }
    return save(place).map { _ in () }
  }

  func isSaved(_ place: RoasterPlace, in saved: [Roaster]) -> Bool {
    saved.contains {
      $0.savedFromMap
        && $0.name.compare(place.name, options: [.caseInsensitive, .diacriticInsensitive])
          == .orderedSame
    }
  }

  private func commit<T>(_ value: () -> T) -> Result<T, StoreError> {
    switch store.save() {
    case .success:
      return .success(value())
    case .failure(let failure):
      store.context.rollback()
      return .failure(failure)
    }
  }
}

/// Words for a failed Apple Maps search that say what actually went wrong. Only a real
/// network failure is called a connection problem.
enum RoasterSearchFailure {
  static func isOffline(_ error: Error) -> Bool {
    guard let url = error as? URLError else { return false }
    return [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost]
      .contains(url.code)
  }

  static func message(for error: Error) -> String {
    if isOffline(error) {
      return "You're offline, so Apple Maps can't search. Check your connection and try again."
    }
    if let map = error as? MKError {
      switch map.code {
      case .loadingThrottled:
        return "Apple Maps is busy right now. Wait a minute and try again."
      case .serverFailure:
        return "Apple Maps didn't answer. Try again, or skip and keep the name as it is."
      default: break
      }
    }
    return "Apple Maps couldn't finish this search. Try again, or skip and keep the name as it is."
  }
}
