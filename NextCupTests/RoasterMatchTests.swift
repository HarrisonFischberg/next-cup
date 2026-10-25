import Foundation
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Roaster match from a bag")
struct RoasterMatchTests {
  private struct FakeSearch: RoasterSearching {
    var places: [RoasterPlace] = [
      RoasterPlace(
        name: "Sample Roasters One", city: "Sampletown",
        website: URL(string: "https://sample-roasters.example"), latitude: 45.52,
        longitude: -122.68)
    ]
    var fails = false
    func search(_ area: SearchArea) async throws -> [RoasterPlace] {
      guard case .named = area else {
        Issue.record("expected a name search")
        return []
      }
      if fails { throw URLError(.notConnectedToInternet) }
      return places
    }
  }

  @Test func searchesByTheRoasterName() async {
    let model = RoasterMatchModel(name: "Sample Roasters", searcher: FakeSearch())
    await model.search()
    #expect(model.phase == .results)
    #expect(model.places.count == 1)
  }

  @Test func noMatchIsAnEmptyResult() async {
    let model = RoasterMatchModel(name: "Nowhere", searcher: FakeSearch(places: []))
    await model.search()
    #expect(model.phase == .results)
    #expect(model.places.isEmpty)
  }

  @Test func aFailedSearchCanBeRetried() async {
    let model = RoasterMatchModel(name: "Sample", searcher: FakeSearch(fails: true))
    await model.search()
    guard case .failed = model.phase else {
      Issue.record("expected a failed phase")
      return
    }
    #expect(model.places.isEmpty)
  }

  @Test func searchingStoresNothing() async throws {
    let container = try NextCupContainer.make(inMemory: true)
    await RoasterMatchModel(name: "Sample", searcher: FakeSearch()).search()
    #expect(try container.mainContext.fetch(FetchDescriptor<Roaster>()).isEmpty)
  }

  @Test func savingABeanWithAPickedPlaceFillsAndLinksTheRoaster() throws {
    let container = try NextCupContainer.make(inMemory: true)
    var fields = BeanFields()
    fields.name = "Washed Ethiopia"
    fields.roasterName = "Sample Roasters One"
    fields.roasterCity = "Sampletown"
    fields.roasterWebsite = URL(string: "https://sample-roasters.example")
    let bean = try BeanService(store: Store(context: container.mainContext)).save(fields).get()
    #expect(bean.roaster?.name == "Sample Roasters One")
    #expect(bean.roaster?.city == "Sampletown")
    #expect(bean.roaster?.website?.host() == "sample-roasters.example")
    #expect(bean.roaster?.savedFromMap == false)
  }

  @Test func skippingKeepsTheTypedRoasterAndAddsNoPlace() throws {
    let container = try NextCupContainer.make(inMemory: true)
    var fields = BeanFields()
    fields.name = "Washed Ethiopia"
    fields.roasterName = "Typed Roasters"
    let bean = try BeanService(store: Store(context: container.mainContext)).save(fields).get()
    #expect(bean.roaster?.name == "Typed Roasters")
    #expect(bean.roaster?.city == nil)
    #expect(bean.roaster?.website == nil)
  }
}
