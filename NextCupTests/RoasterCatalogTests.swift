import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Roaster catalog")
struct RoasterCatalogTests {
  private func catalog() throws -> RoasterCatalog {
    try RoasterCatalog(bundle: .main)
  }

  /// Held by the suite: a context outlives its container only by accident.
  private let container: ModelContainer

  init() throws { container = try NextCupContainer.make(inMemory: true) }

  private func service() throws -> (CatalogService, ModelContext) {
    let context = container.mainContext
    return (CatalogService(store: Store(context: context)), context)
  }

  @Test func bundledCatalogLoadsAndValidates() throws {
    let catalog = try catalog()
    #expect(!catalog.roasters.isEmpty)
    #expect(catalog.roasters.allSatisfy { !$0.coffees.isEmpty })
    #expect(!catalog.checkedOn.isEmpty)
  }

  @Test func duplicateKeysAreRejected() {
    let json = """
      {"version":1,"checkedOn":"2026-10-25","note":"n","roasters":[
      {"key":"a","name":"A","city":"C","region":"R","country":"X","website":"https://a.example","kind":"specialty","coffees":[
      {"key":"c","name":"One","isBlend":false,"isDecaf":false},
      {"key":"c","name":"Two","isBlend":false,"isDecaf":false}]}]}
      """
    #expect(throws: RoasterCatalog.CatalogError.self) { try RoasterCatalog(data: Data(json.utf8)) }
  }

  @Test func addingTwiceReusesBeanAndRoaster() throws {
    let catalog = try catalog()
    let roaster = try #require(catalog.roasters.first)
    let coffee = try #require(roaster.coffees.first)
    let (service, context) = try service()

    let first = try service.addBean(coffee, from: roaster).get()
    let second = try service.addBean(coffee, from: roaster).get()

    #expect(first.created)
    #expect(!second.created)
    #expect(first.bean.id == second.bean.id)
    #expect(try context.fetchCount(FetchDescriptor<Bean>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<Roaster>()) == 1)
    #expect(first.bean.roaster?.website == roaster.website)
    #expect(first.bean.roaster?.city == roaster.city)
  }

  @Test func starterRecipeIsSavedOnceAndTimeable() throws {
    let catalog = try catalog()
    let roaster = try #require(catalog.roasters.first)
    let coffee = try #require(roaster.coffees.first)
    let (service, context) = try service()

    for starter in coffee.starterRecipes {
      let one = try service.recipe(for: starter, coffee: coffee).get()
      let two = try service.recipe(for: starter, coffee: coffee).get()
      #expect(one.id == two.id)
      #expect(one.credit == "Next Cup starting recipe")
      #expect((one.steps ?? []).count == starter.steps.count)
      _ = try TimerPlanBuilder.setup(for: one, doseG: one.doseG)
    }
    #expect(try context.fetchCount(FetchDescriptor<Recipe>()) == coffee.starterRecipes.count)
  }

  // MARK: The catalog and the map

  @Test func aBusinessOnTheMapIsMatchedToItsCatalogRoaster() throws {
    let catalog = try catalog()
    #expect(catalog.roaster(matching: "Onyx Coffee Lab - Rogers")?.key == "onyx")
    #expect(catalog.roaster(matching: "HUCKLEBERRY ROASTERS")?.key == "huckleberry")
    #expect(catalog.roaster(matching: "Peet’s Coffee")?.name == "Peet's Coffee")
    #expect(catalog.roaster(matching: "Counter Coffee") == nil)
    #expect(catalog.roaster(matching: "Sample Roasters One") == nil)
    #expect(catalog.roaster(matching: "Coffee Roasters") == nil)
  }

  @Test func catalogRoastersAmongNearbyPlacesAreMarkedNear() throws {
    let catalog = try catalog()
    let place = { (name: String) in
      RoasterPlace(name: name, city: nil, website: nil, latitude: 1, longitude: 2)
    }
    #expect(
      catalog.roasters(near: [place("Huckleberry Roasters"), place("Sample Roasters One")])
        == ["huckleberry"])
    #expect(catalog.roasters(near: []).isEmpty)
  }

  @Test func oneSearchFindsRoastersAndCoffees() throws {
    let catalog = try catalog()
    #expect(catalog.search("huckle").roasters.map(\.key) == ["huckleberry"])
    #expect(catalog.search("denver").roasters.map(\.key) == ["huckleberry"])
    #expect(catalog.search("kenya rukira").coffees.map(\.id) == ["huck-kenya-rukira"])
    #expect(catalog.search("  ").roasters.isEmpty)
    #expect(catalog.search("zzzz").coffees.isEmpty)
  }

  // MARK: A saved roaster's page

  @Test func roasterStatsCountBeansAndBrewsAndAverageTheRatedOnes() throws {
    let context = container.mainContext
    let roaster = Roaster(name: "Sample Roasters One")
    context.insert(roaster)
    let beans = ["One", "Two"].map { name in
      let bean = Bean(name: name)
      context.insert(bean)
      bean.roaster = roaster
      return bean
    }
    for (bean, rating) in [(beans[0], 80), (beans[0], 70), (beans[1], nil)] {
      let brew = Brew()
      context.insert(brew)
      brew.ratingTenths = rating
      let use = BrewBean(grams: 15, beanNameSnapshot: bean.name)
      context.insert(use)
      use.brew = brew
      use.bean = bean
    }
    try context.save()
    let stats = RoasterStats(beans: roaster.beans ?? [])
    #expect(stats.beans == 2)
    #expect(stats.brews == 3)
    #expect(stats.averageTenths == 75)
    #expect(RoasterStats(beans: []).averageTenths == nil)
  }

  @Test func starterRecipeKindsAreRealStepKinds() {
    for style in StarterStyle.allCases {
      for step in StarterRecipes.recipe(style: style, roast: .light, process: nil).steps {
        #expect(StepKind(rawValue: step.kind) != nil)
      }
    }
  }
}
