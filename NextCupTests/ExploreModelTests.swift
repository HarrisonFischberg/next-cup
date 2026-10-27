import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Explore model")
struct ExploreModelTests {
  @MainActor
  private struct Harness {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws { container = try NextCupContainer.make(inMemory: true) }

    func bean(
      _ name: String, origin: String? = "Ethiopia", process: String? = "Washed",
      roast: RoastLevel? = .light, notes: [String] = ["lemon"], status: BeanStatus = .inUse
    ) -> Bean {
      let bean = Bean(name: name)
      bean.originCountry = origin
      bean.process = process
      bean.roastLevel = roast
      bean.bagFlavorNotes = notes
      bean.status = status
      context.insert(bean)
      return bean
    }

    func method(_ name: String, key: String?) -> BrewMethod {
      let method = BrewMethod(name: name)
      method.builtInKey = key
      context.insert(method)
      return method
    }

    @discardableResult
    func brew(
      _ beans: [Bean], method: BrewMethod?, grade: Int?, day: Int = 0
    ) -> Brew {
      let brew = Brew(date: Date(timeIntervalSince1970: 1_700_000_000 + Double(day) * 86_400))
      brew.ratingTenths = grade
      brew.method = method
      brew.doseG = 15
      brew.waterG = 250
      context.insert(brew)
      for bean in beans {
        let use = BrewBean(grams: 15, beanNameSnapshot: bean.name)
        context.insert(use)
        use.brew = brew
        use.bean = bean
      }
      return brew
    }
  }

  private func taxonomy() throws -> Taxonomy {
    try #require(ExploreModel.taxonomy)
  }

  @Test func beanBucketsComeFromTheBundledTaxonomy() throws {
    let harness = try Harness()
    let bean = harness.bean("Washed Ethiopia")
    let keys = ExploreModel.buckets(of: bean, taxonomy: try taxonomy(), aliases: []).map {
      "\($0.dimension.rawValue):\($0.key)"
    }
    #expect(keys == ["origin:east-africa", "process:washed", "roast:light", "flavor:citrus"])
  }

  @Test func aUserAliasMapsAnUnknownOrigin() throws {
    let harness = try Harness()
    let bean = harness.bean("Estate", origin: "Atlantis")
    let taxonomy = try taxonomy()
    let before = ExploreModel.buckets(of: bean, taxonomy: taxonomy, aliases: [])
    #expect(!before.contains { $0.dimension == .origin })

    let stored = TaxonomyAlias(dimension: .origin, rawValue: "Atlantis", bucketKey: "caribbean")
    let after = ExploreModel.buckets(
      of: bean, taxonomy: taxonomy, aliases: ExploreModel.aliases([stored]))
    #expect(after.contains { $0.dimension == .origin && $0.key == "caribbean" })
  }

  @Test func historySkipsBrewsWithoutAMethod() throws {
    let harness = try Harness()
    let bean = harness.bean("Washed Ethiopia")
    let cone = harness.method("Cone dripper", key: "cone-dripper")
    harness.brew([bean], method: cone, grade: 8)
    harness.brew([bean], method: nil, grade: 8)
    let history = ExploreModel.history(
      of: try harness.context.fetch(FetchDescriptor<Brew>()), taxonomy: try taxonomy(), aliases: [])
    #expect(history.count == 1)
    #expect(history[0].methodKey == "cone-dripper")
    #expect(history[0].ratingTenths == 8)
  }

  @Test func aBlendBrewCarriesTheBucketsOfEveryBean() throws {
    let harness = try Harness()
    let ethiopia = harness.bean("Washed Ethiopia")
    let brazil = harness.bean(
      "Natural Brazil", origin: "Brazil", process: "Natural", roast: .light, notes: [])
    harness.brew([ethiopia, brazil], method: harness.method("Press pot", key: "press"), grade: 8)
    let history = ExploreModel.history(
      of: try harness.context.fetch(FetchDescriptor<Brew>()), taxonomy: try taxonomy(), aliases: [])
    let keys = Set(history[0].buckets.map(\.key))
    #expect(keys.isSuperset(of: ["east-africa", "south-america", "washed", "natural", "light"]))
    #expect(history[0].buckets.count == keys.count)
  }

  @Test func plannedBeansAreTheOnesInUseOrToBuyAgain() throws {
    let harness = try Harness()
    let inUse = harness.bean("A", status: .inUse)
    let again = harness.bean("B", status: .buyAgain)
    _ = harness.bean("C", status: .wishlist)
    _ = harness.bean("D", status: .finished)
    let names = Set(ExploreModel.planned([inUse, again]).map(\.name))
    #expect(names == ["A", "B"])
    #expect(ExploreModel.planned(try harness.context.fetch(FetchDescriptor<Bean>())).count == 2)
  }

  @Test func coldStartIsLabelledAsADefault() throws {
    let harness = try Harness()
    let bean = harness.bean("Washed Ethiopia")
    let taxonomy = try taxonomy()
    let refs = ExploreModel.buckets(of: bean, taxonomy: taxonomy, aliases: [])
    let result = Recommender.recommend(for: refs, history: [])
    #expect(result.isDefault)
    #expect(result.items[0].explanation.contains("not based on your brews"))
  }

  @Test func gradedBrewsOfAlikeBeansDriveTheRecommendation() throws {
    let harness = try Harness()
    let old = harness.bean("Washed Ethiopia", status: .finished)
    let current = harness.bean("Washed Kenya", origin: "Kenya")
    let cone = harness.method("Cone dripper", key: "cone-dripper")
    let press = harness.method("Press pot", key: "press")
    harness.brew([old], method: cone, grade: 90, day: 1)
    harness.brew([old], method: cone, grade: 80, day: 2)
    harness.brew([old], method: press, grade: 50, day: 3)
    let taxonomy = try taxonomy()
    let history = ExploreModel.history(
      of: try harness.context.fetch(FetchDescriptor<Brew>()), taxonomy: taxonomy, aliases: [])
    let refs = ExploreModel.buckets(of: current, taxonomy: taxonomy, aliases: [])
    let result = Recommender.recommend(for: refs, history: history)
    #expect(!result.isDefault)
    #expect(result.items.map(\.methodKey) == ["cone-dripper", "press"])
    #expect(result.items[0].explanation.contains("averaged 8.5 of 10"))
  }

  @Test func hiddenMethodsAreNeverRecommended() throws {
    let harness = try Harness()
    let old = harness.bean("Washed Ethiopia", status: .finished)
    let current = harness.bean("Washed Kenya", origin: "Kenya")
    let press = harness.method("Press pot", key: "press")
    press.isHidden = true
    for day in 1...3 { harness.brew([old], method: press, grade: 90, day: day) }
    let taxonomy = try taxonomy()
    let history = ExploreModel.history(
      of: try harness.context.fetch(FetchDescriptor<Brew>()), taxonomy: taxonomy, aliases: [])
    #expect(history.isEmpty)
    let refs = ExploreModel.buckets(of: current, taxonomy: taxonomy, aliases: [])
    #expect(Recommender.recommend(for: refs, history: history).isDefault)
  }

  @Test func aDefaultBecomesUntriedRecipesOfTheShownMethods() throws {
    let harness = try Harness()
    let bean = harness.bean("Dark Brazil", roast: .dark)
    let press = harness.method("Press pot", key: "press")
    press.isHidden = true
    let switchable = harness.method("Switchable", key: "switchable")
    let tried = Recipe(name: "Tried", doseG: 15, waterG: 250)
    let fresh = Recipe(name: "Fresh", doseG: 18, waterG: 300)
    let pressRecipe = Recipe(name: "Press", doseG: 16, waterG: 250)
    for (recipe, method) in [(tried, switchable), (fresh, switchable), (pressRecipe, press)] {
      harness.context.insert(recipe)
      recipe.method = method
    }
    harness.brew([bean], method: switchable, grade: nil).recipe = tried
    let refs = ExploreModel.buckets(of: bean, taxonomy: try taxonomy(), aliases: [])
    let raw = Recommender.recommend(for: refs, history: [])
    #expect(raw.items[0].methodKey == "press")

    let result = ExploreModel.limited(raw, to: [press, switchable])
    #expect(result.isDefault)
    #expect(result.items.map(\.recipeName) == ["Fresh", "Tried"])
    #expect(result.items.allSatisfy { $0.methodKey == "switchable" })
    #expect(result.items[0].start.doseG == 18)
  }
}
