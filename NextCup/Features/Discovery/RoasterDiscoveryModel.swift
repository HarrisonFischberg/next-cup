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

/// Where to look: around the device (used for the search, never stored) or a
/// city the user typed.
enum SearchArea: Equatable, Sendable {
  case near(latitude: Double, longitude: Double)
  case city(String)
  /// A roaster name read off a bag, looked up to match a real business (T031).
  case named(String)
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
  func currentLocation() async -> LocationOutcome
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

  func retry() async {
    guard !isBusy, let lastArea else { return }
    await run(lastArea)
  }

  private func run(_ area: SearchArea) async {
    lastArea = area
    phase = .searching
    do {
      places = try await searcher.search(area)
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
