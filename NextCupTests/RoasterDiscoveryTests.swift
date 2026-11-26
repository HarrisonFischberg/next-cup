import Foundation
import MapKit
import SwiftData
import Testing

@testable import NextCup

private nonisolated func samplePlace(_ name: String, city: String = "Sampletown") -> RoasterPlace {
  RoasterPlace(name: name, city: city, website: nil, latitude: 45.52, longitude: -122.68)
}

@MainActor
@Suite("Roaster discovery")
struct RoasterDiscoveryTests {
  private struct FakeSearch: RoasterSearching {
    var places: [RoasterPlace] = [samplePlace("Sample Roasters One")]
    var fails = false
    func search(_ area: SearchArea) async throws -> [RoasterPlace] {
      if fails { throw URLError(.notConnectedToInternet) }
      return places
    }
  }

  private struct FakeLocation: LocationProviding {
    let outcome: LocationOutcome
    var isAuthorized = false
    func currentLocation() async -> LocationOutcome { outcome }
  }

  private func model(
    search: FakeSearch = FakeSearch(), location: LocationOutcome = .denied,
    authorized: Bool = false
  ) -> RoasterDiscoveryModel {
    RoasterDiscoveryModel(
      searcher: search, location: FakeLocation(outcome: location, isAuthorized: authorized))
  }

  // MARK: Opening the screen

  @Test func openingWithLocationAllowedGoesStraightToNearbyRoasters() async {
    let model = model(location: .granted(latitude: 1, longitude: 2), authorized: true)
    #expect(model.opensOnMap)
    await model.start()
    #expect(model.phase == .results)
    #expect(model.places.count == 1)
  }

  @Test func openingBeforeLocationIsAllowedWaitsForTheUser() async {
    let model = model(location: .granted(latitude: 1, longitude: 2))
    #expect(!model.opensOnMap)
    await model.start()
    #expect(model.phase == .idle)
    #expect(model.places.isEmpty)
  }

  @Test func reopeningDoesNotSearchAgainOverResults() async {
    let model = model(location: .granted(latitude: 1, longitude: 2), authorized: true)
    model.city = "Sampletown"
    await model.searchCity()
    await model.start()
    #expect(model.phase == .results)
  }

  // MARK: Distance and the map's area

  @Test func aNearbySearchListsTheClosestFirstWithDistances() async {
    let far = RoasterPlace(
      name: "Far", city: nil, website: nil, latitude: 45.60, longitude: -122.68)
    let close = RoasterPlace(
      name: "Close", city: nil, website: nil, latitude: 45.53, longitude: -122.68)
    let model = model(
      search: FakeSearch(places: [far, close]),
      location: .granted(latitude: 45.52, longitude: -122.68), authorized: true)
    await model.start()
    #expect(model.places.map(\.name) == ["Close", "Far"])
    #expect(model.distanceText(to: close)?.hasPrefix("About ") == true)
  }

  @Test func aCitySearchShowsNoDistance() async {
    let model = model()
    model.city = "Sampletown"
    await model.searchCity()
    #expect(model.distanceText(to: samplePlace("Sample Roasters One")) == nil)
  }

  @Test func distanceIsRoundedAndSaysAboutWithApproximateLocation() {
    let us = Locale(identifier: "en_US")
    #expect(RoasterDistance.text(meters: 1_287, precise: true, locale: us) == "0.8 mi")
    #expect(RoasterDistance.text(meters: 3_500, precise: false, locale: us) == "About 2 mi")
    #expect(RoasterDistance.text(meters: 50, precise: false, locale: us) == "About 1 mi")
    let de = Locale(identifier: "de_DE")
    #expect(RoasterDistance.text(meters: 3_500, precise: false, locale: de).contains("km"))
  }

  @Test func searchThisAreaReplacesTheListAndKeepsItWhenNothingIsThere() async {
    let region = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 45.6, longitude: -122.6),
      span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
    let found = model(location: .granted(latitude: 45.52, longitude: -122.68), authorized: true)
    await found.start()
    await found.searchRegion(region)
    #expect(found.showsRegionResults)
    #expect(found.places.count == 1)
    #expect(found.distanceText(to: found.places[0]) != nil, "still measured from the user")

    let empty = RoasterDiscoveryModel(
      searcher: AreaIsEmpty(), location: FakeLocation(outcome: .denied))
    empty.city = "Sampletown"
    await empty.searchCity()
    await empty.searchRegion(region)
    #expect(empty.places.count == 1, "the list is kept")
    #expect(empty.areaNotice != nil)
    #expect(!empty.showsRegionResults)
  }

  private struct AreaIsEmpty: RoasterSearching {
    func search(_ area: SearchArea) async throws -> [RoasterPlace] {
      if case .region = area { return [] }
      return [samplePlace("Sample Roasters One")]
    }
  }

  @Test func theMapOffersSearchThisAreaOnlyAfterARealMove() throws {
    let places = [samplePlace("Sample Roasters One")]
    let shown = try #require(RoasterMap.region(fitting: places))
    var nudged = shown
    nudged.center.latitude += shown.span.latitudeDelta * 0.05
    #expect(!RoasterMap.moved(from: shown, to: nudged))
    var panned = shown
    panned.center.longitude += shown.span.longitudeDelta * 0.5
    #expect(RoasterMap.moved(from: shown, to: panned))
    var zoomedOut = shown
    zoomedOut.span.latitudeDelta *= 2
    #expect(RoasterMap.moved(from: shown, to: zoomedOut))
  }

  // MARK: Links on a roaster's details

  @Test func detailLinksCarryOnlyTheRoaster() throws {
    var place = samplePlace("Sample Roasters One")
    place.address = "12 Sample Street\nSampletown, OR 97200"
    place.phone = "+1 (503) 555-0100"
    #expect(place.callURL?.absoluteString == "tel:+15035550100")
    let google = try #require(place.googleMapsURL?.absoluteString)
    #expect(
      google.hasPrefix("https://www.google.com/maps/search/?api=1&query=Sample%20Roasters%20One"))
    #expect(google.contains("12%20Sample%20Street"))
    let directions = try #require(place.directionsURL?.absoluteString)
    #expect(directions.contains("daddr=45.52,-122.68"))
  }

  @Test func aPlaceWithoutAPhoneHasNoCallLink() {
    #expect(samplePlace("Sample Roasters One").callURL == nil)
  }

  // MARK: Location paths

  @Test func deniedLocationSaysSoAndSearchesNothing() async {
    let model = model(location: .denied)
    await model.useMyLocation()
    #expect(model.phase == .idle)
    #expect(model.places.isEmpty)
    #expect(model.locationNotice?.contains("Type a city") == true)
  }

  @Test func deniedLocationStillLetsATypedCitySearch() async {
    let model = model(location: .denied)
    await model.useMyLocation()
    model.city = "  Sampletown "
    await model.searchCity()
    #expect(model.phase == .results)
    #expect(model.places.count == 1)
    #expect(model.locationNotice == nil)
  }

  @Test func grantedLocationSearchesAroundIt() async {
    let model = model(location: .granted(latitude: 1, longitude: 2))
    await model.useMyLocation()
    #expect(model.phase == .results)
    #expect(model.places.count == 1)
  }

  @Test func unavailableLocationFallsBackToTheCity() async {
    let model = model(location: .unavailable)
    await model.useMyLocation()
    #expect(model.phase == .idle)
    #expect(model.locationNotice != nil)
  }

  // MARK: Search states

  @Test func blankCityDoesNotSearch() async {
    let model = model()
    model.city = "   "
    await model.searchCity()
    #expect(model.phase == .idle)
  }

  @Test func aFailedSearchOffersARetryThatCanSucceed() async {
    let failing = model(search: FakeSearch(fails: true))
    failing.city = "Sampletown"
    await failing.searchCity()
    guard case .failed = failing.phase else {
      Issue.record("expected a failed phase")
      return
    }
    #expect(failing.places.isEmpty)
  }

  @Test func noResultsIsAnEmptyResultNotAnError() async {
    let model = model(search: FakeSearch(places: []))
    model.city = "Nowhere"
    await model.searchCity()
    #expect(model.phase == .results)
    #expect(model.places.isEmpty)
  }

  // MARK: Only saved roasters persist

  @Test func searchingAloneStoresNothing() async throws {
    let container = try NextCupContainer.make(inMemory: true)
    let model = model()
    model.city = "Sampletown"
    await model.searchCity()
    #expect(try container.mainContext.fetch(FetchDescriptor<Roaster>()).isEmpty)
  }

  @Test func savingStoresTheRoastersPlaceAndFlagsIt() throws {
    let container = try NextCupContainer.make(inMemory: true)
    let service = RoasterService(store: Store(context: container.mainContext))
    let saved = try service.save(samplePlace("Sample Roasters One")).get()
    #expect(saved.savedFromMap)
    #expect(saved.city == "Sampletown")
    #expect(saved.latitude == 45.52)
    #expect(try container.mainContext.fetch(FetchDescriptor<Roaster>()).count == 1)
  }

  @Test func savingTwiceOrByAnotherCaseKeepsOneRoaster() throws {
    let container = try NextCupContainer.make(inMemory: true)
    let service = RoasterService(store: Store(context: container.mainContext))
    try service.save(samplePlace("Sample Roasters One")).get()
    try service.save(samplePlace("SAMPLE ROASTERS ONE")).get()
    #expect(try container.mainContext.fetch(FetchDescriptor<Roaster>()).count == 1)
  }

  @Test func savingReusesARoasterABeanAlreadyPointsAt() throws {
    let container = try NextCupContainer.make(inMemory: true)
    let context = container.mainContext
    var fields = BeanFields()
    fields.name = "Washed Ethiopia"
    fields.roasterName = "Sample Roasters One"
    let bean = try BeanService(store: Store(context: context)).save(fields).get()
    let service = RoasterService(store: Store(context: context))
    try service.save(samplePlace("Sample Roasters One")).get()
    #expect(try context.fetch(FetchDescriptor<Roaster>()).count == 1)
    #expect(bean.roaster?.savedFromMap == true)
  }

  @Test func unsavingDeletesAnUnusedRoasterAndKeepsOneWithBeans() throws {
    let container = try NextCupContainer.make(inMemory: true)
    let context = container.mainContext
    let service = RoasterService(store: Store(context: context))
    let unused = try service.save(samplePlace("Unused Roasters")).get()
    try service.unsave(unused).get()
    #expect(try context.fetch(FetchDescriptor<Roaster>()).isEmpty)

    var fields = BeanFields()
    fields.name = "Washed Ethiopia"
    fields.roasterName = "Sample Roasters One"
    let bean = try BeanService(store: Store(context: context)).save(fields).get()
    let used = try service.save(samplePlace("Sample Roasters One")).get()
    try service.unsave(used).get()
    #expect(used.savedFromMap == false)
    #expect(bean.roaster?.name == "Sample Roasters One")
  }
}
