import Foundation
import SwiftData
import Testing

@testable import NextCup

@Suite(.serialized) @MainActor struct BuiltInSeederTests {
  private func makeSeeder() throws -> (BuiltInSeeder, ModelContainer) {
    let container = try NextCupContainer.make(inMemory: true)
    let suite = "BuiltInSeederTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    return (
      BuiltInSeeder(store: Store(context: container.mainContext), defaults: defaults), container
    )
  }

  private func bundled() throws -> BuiltInContent { try BuiltInContent(bundle: .main) }

  private func jsonObject(_ name: String) throws -> [String: Any] {
    let url = try #require(Bundle.main.url(forResource: name, withExtension: "json"))
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    return try #require(object as? [String: Any])
  }

  // MARK: Bundle content

  @Test func bundleLoadsAndReferencesResolve() throws {
    let content = try bundled()
    #expect(content.methodsVersion >= 1)
    #expect(content.recipesVersion >= 1)
    let methodKeys = content.methods.map(\.key)
    #expect(Set(methodKeys).count == methodKeys.count)
    let recipeKeys = content.recipes.map(\.key)
    #expect(Set(recipeKeys).count == recipeKeys.count)
    for recipe in content.recipes {
      #expect(methodKeys.contains(recipe.methodKey), "\(recipe.key) names an unknown method")
      #expect(!recipe.steps.isEmpty, "\(recipe.key) has no steps")
      #expect(recipe.doseG > 0 && recipe.waterG > 0)
      let offsets = recipe.steps.map(\.startOffsetS)
      #expect(offsets == offsets.sorted(), "\(recipe.key) steps are out of time order")
      let targets = recipe.steps.compactMap(\.targetCumulativeWaterG)
      #expect(targets == targets.sorted(), "\(recipe.key) water targets go backwards")
      #expect(recipe.includesIce == (recipe.iceG != nil))
    }
  }

  @Test func bundleHasSwitchableDripperAndInvertedPress() throws {
    let content = try bundled()
    let methods = Dictionary(uniqueKeysWithValues: content.methods.map { ($0.key, $0) })
    #expect(methods["switchable-dripper"]?.defaultStepKinds.contains(.openValve) == true)
    #expect(methods["switchable-dripper"]?.defaultStepKinds.contains(.closeValve) == true)
    #expect(methods["inverted-press"]?.defaultStepKinds.contains(.invert) == true)
    #expect(content.recipes.contains { $0.methodKey == "switchable-dripper" })
    #expect(content.recipes.contains { $0.methodKey == "inverted-press" })
  }

  @Test func everyStyleHasABuiltInMethod() throws {
    let styles = Set(try bundled().methods.map(\.style))
    #expect(styles == Set(BrewStyle.allCases))
  }

  @Test func taxonomyMapsOnlyToDeclaredBuckets() throws {
    let file = try jsonObject("taxonomy")
    #expect((file["version"] as? Int ?? 0) >= 1)
    let dimensions = try #require(file["dimensions"] as? [String: [String: Any]])
    #expect(Set(dimensions.keys) == Set(TaxonomyDimension.allCases.map(\.rawValue)))
    for (name, dimension) in dimensions {
      let buckets = try #require(dimension["buckets"] as? [[String: String]])
      let keys = Set(buckets.compactMap { $0["key"] })
      #expect(keys.count == buckets.count, "\(name) repeats a bucket key")
      let map = try #require(dimension["map"] as? [String: String])
      #expect(!map.isEmpty)
      for (raw, bucket) in map {
        #expect(keys.contains(bucket), "\(name): '\(raw)' maps to unknown bucket '\(bucket)'")
        #expect(raw == raw.lowercased(), "\(name): '\(raw)' is not normalized")
      }
    }
    let roastMap = try #require(dimensions["roast"]?["map"] as? [String: String])
    for level in RoastLevel.allCases {
      #expect(roastMap[level.rawValue.lowercased()] != nil, "\(level) has no roast band")
    }
    let brewerBuckets = try #require(dimensions["brewer"]?["buckets"] as? [[String: String]])
    #expect(Set(brewerBuckets.compactMap { $0["key"] }) == Set(BrewStyle.allCases.map(\.rawValue)))
  }

  // MARK: Seeding

  @Test func seedingCreatesMethodsRecipesAndSteps() throws {
    let (seeder, container) = try makeSeeder()
    let content = try bundled()
    let report = try seeder.seed(content).get()
    #expect(
      report == .init(methodsAdded: content.methods.count, recipesAdded: content.recipes.count))

    let context = container.mainContext
    let methods = try context.fetch(FetchDescriptor<BrewMethod>())
    #expect(Set(methods.compactMap(\.builtInKey)) == Set(content.methods.map(\.key)))
    #expect(Set(methods.map(\.sortOrder)).count == methods.count)

    let recipes = try context.fetch(FetchDescriptor<Recipe>())
    #expect(recipes.count == content.recipes.count)
    for recipe in recipes {
      let entry = try #require(content.recipes.first { $0.key == recipe.builtInKey })
      #expect(recipe.method?.builtInKey == entry.methodKey)
      let steps = (recipe.steps ?? []).sorted { $0.order < $1.order }
      #expect(steps.map(\.kind) == entry.steps.map(\.kind))
      #expect(steps.map(\.order) == Array(0..<entry.steps.count))
    }
  }

  @Test func seedingTwiceCreatesNoDuplicates() throws {
    let (seeder, container) = try makeSeeder()
    let content = try bundled()
    try seeder.seed(content).get()
    let second = try seeder.seed(content).get()
    #expect(second == .init(methodsAdded: 0, recipesAdded: 0))
    let context = container.mainContext
    #expect(try context.fetchCount(FetchDescriptor<BrewMethod>()) == content.methods.count)
    #expect(try context.fetchCount(FetchDescriptor<Recipe>()) == content.recipes.count)
    let stepCount = content.recipes.flatMap(\.steps).count
    #expect(try context.fetchCount(FetchDescriptor<RecipeStep>()) == stepCount)
  }

  @Test func newerBundleAddsKeysWithoutOverwritingEdits() throws {
    let (seeder, container) = try makeSeeder()
    var content = try bundled()
    try seeder.seed(content).get()

    let context = container.mainContext
    let cone = try #require(
      try context.fetch(FetchDescriptor<BrewMethod>()).first { $0.builtInKey == "cone-dripper" })
    cone.name = "My cone"
    cone.isHidden = true
    let recipe = try #require(
      try context.fetch(FetchDescriptor<Recipe>()).first { $0.builtInKey == "cone-balanced" })
    recipe.doseG = 17

    var newMethod = content.methods[0]
    newMethod.key = "new-method"
    newMethod.name = "Added later"
    var newRecipe = content.recipes[0]
    newRecipe.key = "new-recipe"
    newRecipe.methodKey = "new-method"
    content.methodsVersion += 1
    content.recipesVersion += 1
    content.methods[0].name = "Renamed in bundle"
    content.recipes[0].doseG = 99
    content.methods.append(newMethod)
    content.recipes.append(newRecipe)

    let report = try seeder.seed(content).get()
    #expect(report == .init(methodsAdded: 1, recipesAdded: 1))
    #expect(cone.name == "My cone")
    #expect(cone.isHidden)
    #expect(recipe.doseG == 17)
    let added = try #require(
      try context.fetch(FetchDescriptor<Recipe>()).first { $0.builtInKey == "new-recipe" })
    #expect(added.method?.builtInKey == "new-method")
  }

  @Test func deletedBuiltInStaysDeletedUntilReset() throws {
    let (seeder, container) = try makeSeeder()
    let content = try bundled()
    try seeder.seed(content).get()
    let context = container.mainContext
    let recipe = try #require(
      try context.fetch(FetchDescriptor<Recipe>()).first { $0.builtInKey == "cone-balanced" })
    context.delete(recipe)
    try context.save()

    try seeder.seed(content).get()
    #expect(try context.fetchCount(FetchDescriptor<Recipe>()) == content.recipes.count - 1)

    seeder.forgetOfferedKeys()
    let report = try seeder.seed(content).get()
    #expect(report == .init(methodsAdded: 0, recipesAdded: 1))
    #expect(try context.fetchCount(FetchDescriptor<Recipe>()) == content.recipes.count)
  }
}
