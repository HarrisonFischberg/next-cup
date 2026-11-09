import Foundation
import SwiftData
import Testing

@testable import NextCup

@Suite(.serialized) @MainActor struct RecipeSnapshotTests {
  /// Held for the whole test: a context outlived by its container loses its rows.
  let container: ModelContainer

  init() throws { container = try NextCupContainer.make(inMemory: true) }

  /// A user recipe with a method and two steps, and a brew made from it, saved.
  private func brewed() throws -> (Store, Recipe, Brew) {
    let store = Store(context: container.mainContext)
    let method = BrewMethod(name: "Cone dripper")
    method.symbol = "drop"
    let recipe = Recipe(name: "Sunday bloom", doseG: 15, waterG: 250)
    (recipe.tempC, recipe.totalTimeS, recipe.grindSetting) = (94, 180, "18")
    store.context.insert(method)
    store.context.insert(recipe)
    recipe.method = method
    recipe.steps = [
      RecipeStep(order: 1, kind: .pour, startOffsetS: 45),
      RecipeStep(order: 0, kind: .bloom, startOffsetS: 0),
    ]
    recipe.steps?[0].targetCumulativeWaterG = 250
    let brew = Brew()
    store.context.insert(brew)
    brew.recipe = recipe
    brew.snapshotRecipe()
    try store.save().get()
    return (store, recipe, brew)
  }

  @Test func snapshotKeepsTheRecipeAsBrewed() throws {
    let (_, recipe, brew) = try brewed()
    let snapshot = try #require(brew.recipeSnapshot)
    #expect(snapshot.recipeID == recipe.id)
    #expect(snapshot.name == "Sunday bloom")
    #expect(snapshot.methodName == "Cone dripper")
    #expect(snapshot.methodSymbol == "drop")
    #expect((snapshot.doseG, snapshot.waterG, snapshot.tempC) == (15, 250, 94))
    #expect(snapshot.grindSetting == "18")
    #expect(snapshot.steps.map(\.kind) == [.bloom, .pour])
    #expect(snapshot.steps.last?.targetCumulativeWaterG == 250)

    // Editing the recipe later leaves the brew's snapshot alone.
    recipe.doseG = 20
    brew.snapshotRecipe()
    #expect(brew.recipeSnapshot?.doseG == 15)
  }

  @Test func brewWithoutRecipeHasNoSnapshotOrLine() {
    let brew = Brew()
    brew.snapshotRecipe()
    #expect(brew.recipeSnapshotJSON == nil)
    #expect(BrewRecipeInfo(brew) == nil)
    #expect(BrewRecipeAction(brew) == nil)
  }

  @Test func snapshotSurvivesDeletingTheRecipe() throws {
    let (store, recipe, brew) = try brewed()
    #expect(throws: Never.self) { try RecipeEditorService(store: store).delete(recipe).get() }
    let fresh = try #require(
      try ModelContext(container).fetch(FetchDescriptor<Brew>()).first)
    #expect(fresh.recipe == nil)
    #expect(fresh.recipeSnapshot?.name == "Sunday bloom")
    let info = try #require(BrewRecipeInfo(fresh))
    #expect(info.isDeleted)
    #expect(info.symbol == "drop")
    #expect(info.accessibilityLabel.contains("Recipe deleted"))
  }

  /// A brew linked before snapshots existed gets one when its recipe is deleted.
  @Test func deletingSnapshotsBrewsThatHadNone() throws {
    let (store, recipe, brew) = try brewed()
    brew.recipeSnapshotJSON = nil
    try store.save().get()
    #expect(throws: Never.self) { try RecipeEditorService(store: store).delete(recipe).get() }
    #expect(brew.recipeSnapshot?.name == "Sunday bloom")
  }

  @Test func restoreRecreatesTheRecipeAndRelinksEveryBrew() throws {
    let (store, recipe, brew) = try brewed()
    let recipeID = recipe.id
    let other = Brew()
    store.context.insert(other)
    other.recipe = recipe
    other.snapshotRecipe()
    try store.save().get()
    try RecipeEditorService(store: store).delete(recipe).get()

    let restored = try store.restoreRecipe(for: brew).get()
    #expect(restored.id == recipeID)
    #expect(restored.builtInKey == nil)
    #expect(restored.method?.name == "Cone dripper")
    #expect((restored.doseG, restored.waterG, restored.tempC) == (15, 250, 94))
    #expect(restored.orderedSteps.map(\.kind) == [.bloom, .pour])
    #expect(brew.recipe?.id == recipeID)
    #expect(other.recipe?.id == recipeID)
    #expect(try store.context.fetch(FetchDescriptor<Recipe>()).count == 1)

    // Saving it again while it exists relinks, never copies.
    brew.recipe = nil
    _ = try store.restoreRecipe(for: brew).get()
    #expect(try store.context.fetch(FetchDescriptor<Recipe>()).count == 1)
    #expect(brew.recipe?.id == recipeID)
  }

  @Test func favoriteRecipeWorksBeforeAndAfterRestoring() throws {
    let (store, recipe, brew) = try brewed()
    #expect(BrewRecipeAction(brew)?.title == "Favorite recipe")
    #expect(BrewRecipeAction(brew)?.perform(on: brew, store: store, reduceMotion: true) == nil)
    #expect(recipe.isFavorite)
    #expect(!brew.isFavorite)  // the brew's own star is separate
    #expect(BrewRecipeAction(brew)?.title == "Unfavorite recipe")

    try RecipeEditorService(store: store).delete(recipe).get()
    #expect(BrewRecipeAction(brew)?.title == "Save recipe again")
    #expect(BrewRecipeAction(brew)?.perform(on: brew, store: store, reduceMotion: true) == nil)
    #expect(BrewRecipeAction(brew)?.title == "Favorite recipe")
    #expect(BrewRecipeAction(brew)?.perform(on: brew, store: store, reduceMotion: true) == nil)
    #expect(brew.recipe?.isFavorite == true)
    #expect(BrewRecipeInfo(brew)?.isFavorite == true)
  }

  @Test func backfillSnapshotsLinkedBrewsOnce() throws {
    let (store, _, brew) = try brewed()
    brew.recipeSnapshotJSON = nil
    try store.save().get()
    let defaults = try #require(UserDefaults(suiteName: "snapshot.\(UUID().uuidString)"))
    #expect(throws: Never.self) {
      try RecipeSnapshotBackfill.run(store.context, defaults: defaults).get()
    }
    #expect(brew.recipeSnapshot?.name == "Sunday bloom")
    #expect(defaults.bool(forKey: RecipeSnapshotBackfill.doneKey))
  }

  @Test func backfillLinksOneConfidentMatchAndLeavesTheRestAlone() throws {
    let (store, recipe, _) = try brewed()
    let method = try #require(recipe.method)
    func unlinked(_ dose: Double, _ water: Double, grind: String? = nil) -> Brew {
      let brew = Brew()
      store.context.insert(brew)
      (brew.method, brew.doseG, brew.waterG, brew.grindSetting) = (method, dose, water, grind)
      return brew
    }
    let close = unlinked(15.2, 252)
    let otherGrind = unlinked(15, 250, grind: "30")
    let far = unlinked(20, 320)
    let noMethod = Brew()
    (noMethod.doseG, noMethod.waterG) = (15, 250)
    store.context.insert(noMethod)
    try store.save().get()

    let defaults = try #require(UserDefaults(suiteName: "snapshot.\(UUID().uuidString)"))
    try RecipeSnapshotBackfill.run(store.context, defaults: defaults).get()
    #expect(close.recipe?.id == recipe.id)
    #expect(close.recipeSnapshot?.name == "Sunday bloom")
    for left in [otherGrind, far, noMethod] {
      #expect(left.recipe == nil)
      #expect(left.recipeSnapshotJSON == nil)
    }

    // Running again (even past the done flag) changes nothing.
    let before = try store.context.fetch(FetchDescriptor<Brew>()).map {
      ($0.recipe?.id, $0.recipeSnapshotJSON)
    }
    try RecipeSnapshotBackfill.run(store.context, defaults: defaults).get()
    defaults.removeObject(forKey: RecipeSnapshotBackfill.doneKey)
    try RecipeSnapshotBackfill.run(store.context, defaults: defaults).get()
    let after = try store.context.fetch(FetchDescriptor<Brew>()).map {
      ($0.recipe?.id, $0.recipeSnapshotJSON)
    }
    #expect(before.map(\.0) == after.map(\.0))
    #expect(before.map(\.1) == after.map(\.1))
  }

  @Test func backfillSkipsAmbiguousMatches() throws {
    let (store, recipe, _) = try brewed()
    let twin = Recipe(name: "Sunday bloom twin", doseG: 15, waterG: 250)
    store.context.insert(twin)
    twin.method = recipe.method
    let brew = Brew()
    store.context.insert(brew)
    (brew.method, brew.doseG, brew.waterG) = (recipe.method, 15, 250)
    try store.save().get()
    let defaults = try #require(UserDefaults(suiteName: "snapshot.\(UUID().uuidString)"))
    try RecipeSnapshotBackfill.run(store.context, defaults: defaults).get()
    #expect(brew.recipe == nil)
    #expect(brew.recipeSnapshotJSON == nil)
  }

  @Test func archiveCarriesTheSnapshot() throws {
    let (_, _, brew) = try brewed()
    let record = try JSONDecoder().decode(
      BrewRecord.self, from: JSONEncoder().encode(BrewRecord(brew)))
    let copied = Brew()
    record.copy(to: copied)
    #expect(copied.recipeSnapshot == brew.recipeSnapshot)

    // Archives from before snapshots have no key and still read.
    var json =
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as! [String: Any]
    json.removeValue(forKey: "recipeSnapshotJSON")
    let old = try JSONDecoder().decode(
      BrewRecord.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(old.recipeSnapshotJSON == nil)
  }
}
