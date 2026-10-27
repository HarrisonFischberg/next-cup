import Foundation
import SwiftData

/// Seeds bundled methods and recipes once per `builtInKey`.
///
/// - Running it again creates nothing (idempotent).
/// - A newer bundle adds only keys it has not offered before; a row the user has
///   edited or deleted is never touched or brought back.
///
/// Offered keys live in `defaults` (blueprint §5, client preferences). Delete-all
/// clears all of `defaults` before reseeding, so every built-in comes back.
@MainActor
struct BuiltInSeeder {
  struct Report: Equatable {
    var methodsAdded: Int
    var recipesAdded: Int
  }

  static let methodsLedgerKey = "builtIn.offeredMethodKeys"
  static let recipesLedgerKey = "builtIn.offeredRecipeKeys"

  let store: Store
  let defaults: UserDefaults

  func seed(_ content: BuiltInContent) -> Result<Report, StoreError> {
    do {
      let offeredMethods = Set(defaults.stringArray(forKey: Self.methodsLedgerKey) ?? [])
      let offeredRecipes = Set(defaults.stringArray(forKey: Self.recipesLedgerKey) ?? [])
      let methods = try store.context.fetch(FetchDescriptor<BrewMethod>())
      var methodsByKey = Dictionary(
        methods.compactMap { method in method.builtInKey.map { ($0, method) } },
        uniquingKeysWith: { first, _ in first })
      let existingRecipeKeys = Set(
        try store.context.fetch(FetchDescriptor<Recipe>()).compactMap(\.builtInKey))

      var report = Report(methodsAdded: 0, recipesAdded: 0)
      var nextSortOrder = (methods.map(\.sortOrder).max() ?? -1) + 1

      for entry in content.methods
      where !offeredMethods.contains(entry.key) && methodsByKey[entry.key] == nil {
        let method = BrewMethod(name: entry.name, style: entry.style)
        method.symbol = entry.symbol
        method.trackedParameters = entry.trackedParameters
        method.defaultStepKinds = entry.defaultStepKinds
        method.sortOrder = nextSortOrder
        method.builtInKey = entry.key
        // A method added by an update waits under More methods; the first seed shows all
        // and onboarding lets the user pick.
        method.isHidden = !offeredMethods.isEmpty
        nextSortOrder += 1
        store.context.insert(method)
        methodsByKey[entry.key] = method
        report.methodsAdded += 1
      }

      for entry in content.recipes
      where !offeredRecipes.contains(entry.key) && !existingRecipeKeys.contains(entry.key) {
        let recipe = Recipe(name: entry.name, doseG: entry.doseG, waterG: entry.waterG)
        recipe.tempC = entry.tempC
        recipe.totalTimeS = entry.totalTimeS
        recipe.tuningNote = entry.tuningNote
        recipe.includesIce = entry.includesIce
        recipe.iceG = entry.iceG
        recipe.credit = entry.credit
        recipe.creditURL = entry.creditURL
        recipe.builtInKey = entry.key
        recipe.method = methodsByKey[entry.methodKey]
        store.context.insert(recipe)
        recipe.steps = entry.steps.enumerated().map { index, step in
          let model = RecipeStep(order: index, kind: step.kind, startOffsetS: step.startOffsetS)
          model.targetCumulativeWaterG = step.targetCumulativeWaterG
          model.instruction = step.instruction
          return model
        }
        report.recipesAdded += 1
      }

      if case .failure(let error) = store.save() { return .failure(error) }

      // Recorded only after a confirmed write, so a failed save retries next launch.
      defaults.set(
        Array(offeredMethods.union(content.methods.map(\.key))).sorted(),
        forKey: Self.methodsLedgerKey)
      defaults.set(
        Array(offeredRecipes.union(content.recipes.map(\.key))).sorted(),
        forKey: Self.recipesLedgerKey)
      return .success(report)
    } catch {
      return .failure(.saveFailed(error.localizedDescription))
    }
  }
}
