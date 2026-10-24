import Foundation
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
    func currentLocation() async -> LocationOutcome { outcome }
  }

  private func model(
    search: FakeSearch = FakeSearch(), location: LocationOutcome = .denied
  ) -> RoasterDiscoveryModel {
    RoasterDiscoveryModel(searcher: search, location: FakeLocation(outcome: location))
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
