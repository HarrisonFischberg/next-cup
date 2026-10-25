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

  private func service() throws -> (CatalogService, ModelContext) {
    let container = try NextCupContainer.make(inMemory: true)
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

  @Test func starterRecipeKindsAreRealStepKinds() {
    for style in StarterStyle.allCases {
      for step in StarterRecipes.recipe(style: style, roast: .light, process: nil).steps {
        #expect(StepKind(rawValue: step.kind) != nil)
      }
    }
  }
}
