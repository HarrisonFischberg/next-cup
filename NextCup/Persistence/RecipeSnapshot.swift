import Foundation
import SwiftData

/// The recipe a brew was made with, as it stood when the brew was saved. Kept on the brew as
/// JSON (`Brew.recipeSnapshotJSON`), so the journal still names the recipe after it is deleted
/// and can save it again. Add fields as optionals only, or older snapshots stop reading.
struct RecipeSnapshot: Codable, Equatable, Sendable {
  struct Step: Codable, Equatable, Sendable {
    var kind: StepKind
    var startOffsetS: Int
    var targetCumulativeWaterG: Double?
    var instruction: String
  }

  var recipeID: UUID
  var name: String
  var methodID: UUID?
  var methodName: String?
  var methodSymbol: String?
  var credit: String?
  var creditURL: URL?
  var doseG: Double
  var waterG: Double
  var tempC: Double?
  var totalTimeS: Int?
  var tuningNote: String?
  var includesIce: Bool
  var iceG: Double?
  var grindSetting: String?
  var grinderName: String?
  /// The recipe's `updatedAt` when the brew was saved: which version of it was brewed.
  var recipeUpdatedAt: Date
  var steps: [Step]

  init(_ recipe: Recipe) {
    (recipeID, name, recipeUpdatedAt) = (recipe.id, recipe.name, recipe.updatedAt)
    (methodID, methodName, methodSymbol) = (
      recipe.method?.id, recipe.method?.name, recipe.method?.symbol
    )
    (credit, creditURL, doseG, waterG) = (
      recipe.credit, recipe.creditURL, recipe.doseG, recipe.waterG
    )
    (tempC, totalTimeS, tuningNote) = (recipe.tempC, recipe.totalTimeS, recipe.tuningNote)
    (includesIce, iceG) = (recipe.includesIce, recipe.iceG)
    (grindSetting, grinderName) = (recipe.grindSetting, recipe.grinderName)
    steps = recipe.orderedSteps.map {
      Step(
        kind: $0.kind, startOffsetS: $0.startOffsetS,
        targetCumulativeWaterG: $0.targetCumulativeWaterG, instruction: $0.instruction)
    }
  }

  /// The recipe again in `context`, with its old id, as the user's own (never a built-in).
  func make(method: BrewMethod?, in context: ModelContext) -> Recipe {
    let recipe = Recipe(id: recipeID, name: name, doseG: doseG, waterG: waterG)
    context.insert(recipe)
    (recipe.credit, recipe.creditURL, recipe.tempC) = (credit, creditURL, tempC)
    (recipe.totalTimeS, recipe.tuningNote) = (totalTimeS, tuningNote)
    (recipe.includesIce, recipe.iceG) = (includesIce, iceG)
    (recipe.grindSetting, recipe.grinderName) = (grindSetting, grinderName)
    recipe.method = method
    recipe.steps = steps.enumerated().map { index, step in
      let model = RecipeStep(order: index, kind: step.kind, startOffsetS: step.startOffsetS)
      model.targetCumulativeWaterG = step.targetCumulativeWaterG
      model.instruction = step.instruction
      return model
    }
    return recipe
  }
}

extension Brew {
  var recipeSnapshot: RecipeSnapshot? {
    get { recipeSnapshotJSON.flatMap { try? JSONDecoder().decode(RecipeSnapshot.self, from: $0) } }
    set { recipeSnapshotJSON = newValue.flatMap { try? JSONEncoder().encode($0) } }
  }

  /// Snapshots the linked recipe when the brew first links to it. A brew edited later keeps
  /// the recipe as it was brewed, not as it has been edited since.
  func snapshotRecipe() {
    guard let recipe, recipeSnapshot?.recipeID != recipe.id else { return }
    recipeSnapshot = RecipeSnapshot(recipe)
  }
}

extension Store {
  /// Saves a brew's deleted recipe again from its snapshot, as the user's recipe with its old
  /// id, and relinks every brew that used it. A recipe that still exists is relinked, not
  /// copied. A failed save is rolled back.
  func restoreRecipe(for brew: Brew) -> Result<Recipe, StoreError> {
    guard let snapshot = brew.recipeSnapshot else {
      return .failure(.saveFailed("This brew has no recipe saved with it."))
    }
    let recipe: Recipe
    if let existing = try? find(Recipe.self, id: snapshot.recipeID) {
      recipe = existing
    } else {
      let methods = (try? context.fetch(FetchDescriptor<BrewMethod>())) ?? []
      let method =
        methods.first { $0.id == snapshot.methodID }
        ?? methods.first { $0.name == snapshot.methodName }
      recipe = snapshot.make(method: method, in: context)
    }
    // Rare, so every brew is read rather than trusting a predicate on the relationship.
    for other in (try? context.fetch(FetchDescriptor<Brew>())) ?? []
    where other.recipe == nil && other.recipeSnapshot?.recipeID == snapshot.recipeID {
      other.recipe = recipe
    }
    brew.recipe = recipe
    switch save() {
    case .success: return .success(recipe)
    case .failure(let error):
      context.rollback()
      return .failure(error)
    }
  }
}

/// Gives older brews their recipe line, once: a brew linked to a recipe gets its snapshot, and
/// a brew with no recipe is linked to one only when exactly one recipe clearly matches it.
/// Running it again changes nothing.
@MainActor
enum RecipeSnapshotBackfill {
  static let doneKey = "brew.recipeSnapshotsBackfilled"
  /// How close a brew's numbers must be to a recipe's to count as made from it.
  static let doseToleranceG = 0.5
  static let waterToleranceG = 5.0

  static func run(
    _ context: ModelContext, defaults: UserDefaults = .standard
  ) -> Result<Void, StoreError> {
    guard !defaults.bool(forKey: doneKey) else { return .success(()) }
    let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
    for brew in (try? context.fetch(FetchDescriptor<Brew>())) ?? []
    where brew.recipeSnapshotJSON == nil {
      if brew.recipe == nil, let match = match(brew, in: recipes) { brew.recipe = match }
      brew.snapshotRecipe()
    }
    if case .failure(let error) = Store(context: context).save() { return .failure(error) }
    defaults.set(true, forKey: doneKey)
    return .success(())
  }

  /// The one recipe on the brew's method whose dose and water match the brew's (and its grind,
  /// when both have one). None, or more than one, is no match: a wrong recipe is worse than none.
  static func match(_ brew: Brew, in recipes: [Recipe]) -> Recipe? {
    guard let method = brew.method?.id, let dose = brew.doseG, let water = brew.waterG else {
      return nil
    }
    let grind = brew.grindSetting?.trimmingCharacters(in: .whitespaces)
    let matches = recipes.filter { recipe in
      recipe.method?.id == method
        && abs(recipe.doseG - dose) <= doseToleranceG
        && abs(recipe.waterG - water) <= waterToleranceG
        && (grind == nil || recipe.grindSetting == nil || recipe.grindSetting == grind)
    }
    return matches.count == 1 ? matches[0] : nil
  }
}
