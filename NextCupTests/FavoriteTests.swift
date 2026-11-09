import Foundation
import SwiftData
import Testing

@testable import NextCup

@Suite(.serialized) @MainActor struct FavoriteTests {
  @Test func recipesAndBrewsStartUnstarred() {
    #expect(!Recipe().isFavorite)
    #expect(!Brew().isFavorite)
  }

  @Test func toggleStarsUnstarsAndSaves() throws {
    let container = try NextCupContainer.make(inMemory: true)
    let store = Store(context: container.mainContext)
    let recipe = Recipe(name: "Loved")
    let brew = Brew()
    store.context.insert(recipe)
    store.context.insert(brew)
    #expect(throws: Never.self) { try store.save().get() }

    #expect(throws: Never.self) { try store.toggleFavorite(recipe, \.isFavorite).get() }
    #expect(throws: Never.self) { try store.toggleFavorite(brew, \.isFavorite).get() }
    let fresh = ModelContext(container)
    #expect(try fresh.fetch(FetchDescriptor<Recipe>()).first?.isFavorite == true)
    #expect(try fresh.fetch(FetchDescriptor<Brew>()).first?.isFavorite == true)

    #expect(throws: Never.self) { try store.toggleFavorite(recipe, \.isFavorite).get() }
    #expect(try ModelContext(container).fetch(FetchDescriptor<Recipe>()).first?.isFavorite == false)
  }

  @Test func archiveKeepsTheStar() throws {
    let recipe = Recipe(name: "Loved")
    recipe.isFavorite = true
    let brew = Brew()
    brew.isFavorite = true
    let copiedRecipe = Recipe()
    RecipeRecord(recipe).copy(to: copiedRecipe)
    let copiedBrew = Brew()
    BrewRecord(brew).copy(to: copiedBrew)
    #expect(copiedRecipe.isFavorite)
    #expect(copiedBrew.isFavorite)
  }

  /// Archives written before favorites have no key; they read as not starred.
  @Test func oldArchiveReadsUnstarred() throws {
    let recipe = Recipe(name: "Old")
    recipe.isFavorite = true
    var json =
      try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(RecipeRecord(recipe))) as! [String: Any]
    json.removeValue(forKey: "isFavorite")
    let record = try JSONDecoder().decode(
      RecipeRecord.self, from: JSONSerialization.data(withJSONObject: json))
    let restored = Recipe()
    restored.isFavorite = true
    record.copy(to: restored)
    #expect(!restored.isFavorite)
  }
}
