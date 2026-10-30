import Foundation
import NextCupKit
import SwiftData

/// One step in an editable recipe. Water is grams, time is seconds (storage units).
struct RecipeStepDraft: Identifiable, Hashable {
  var id = UUID()
  var kind: StepKind = .pour
  var startOffsetS = 0
  var targetCumulativeWaterG: Double?
  var instruction = ""
}

/// A recipe as the editor holds it. Plain values, so it round-trips through the
/// store without a live model and can be compared in tests.
struct RecipeDraft: Hashable {
  /// The recipe saved in place. `nil` saves a new recipe (new, or a customized copy).
  var sourceID: UUID?
  var name = ""
  var methodID: UUID?
  var credit: String?
  var creditURL: URL?
  var doseG = 0.0
  var waterG = 0.0
  var tempC: Double?
  var totalTimeS: Int?
  var tuningNote: String?
  var includesIce = false
  var iceG: Double?
  var steps: [RecipeStepDraft] = []
}

enum RecipeEditorError: Error, Equatable {
  case emptyName
  case invalidDose
  case invalidWater
  case invalidIce
  case negativeTime(step: Int)
  case targetGoesBackwards(step: Int)
  case targetExceedsWater(step: Int)
  case notFound
  case unreadable(field: String)
  case saveFailed(String)

  var message: String {
    switch self {
    case .unreadable(let field): "\(field) is not a number or time the editor can read."
    case .emptyName: "Give the recipe a name."
    case .invalidDose: "Dose must be more than zero."
    case .invalidWater: "Water must be more than zero."
    case .invalidIce: "Add the ice weight, or turn ice off."
    case .negativeTime(let step): "Step \(step) starts before zero."
    case .targetGoesBackwards(let step):
      "Step \(step) has less water than an earlier step. Targets are running totals."
    case .targetExceedsWater(let step): "Step \(step) has more water than the recipe uses."
    case .notFound: "This recipe is no longer in your library."
    case .saveFailed(let reason): "The recipe could not be saved: \(reason)"
    }
  }
}

/// Reads a recipe into a draft and writes a draft back (S08). A built-in recipe is
/// never edited in place: customizing it saves a separate copy, so the bundled
/// original stays as shipped. A failed write is rolled back and returned.
@MainActor
struct RecipeEditorService {
  let store: Store

  private var context: ModelContext { store.context }

  /// The draft for editing `recipe`. `asCopy` clears the link to the original, so
  /// saving makes a new recipe (used for built-ins and Duplicate).
  func draft(from recipe: Recipe, asCopy: Bool) -> RecipeDraft {
    RecipeDraft(
      sourceID: asCopy ? nil : recipe.id,
      name: asCopy ? "\(recipe.name) (copy)" : recipe.name,
      methodID: recipe.method?.id, credit: recipe.credit, creditURL: recipe.creditURL,
      doseG: recipe.doseG, waterG: recipe.waterG, tempC: recipe.tempC,
      totalTimeS: recipe.totalTimeS, tuningNote: recipe.tuningNote,
      includesIce: recipe.includesIce, iceG: recipe.iceG,
      steps: recipe.orderedSteps.map {
        RecipeStepDraft(
          kind: $0.kind, startOffsetS: $0.startOffsetS,
          targetCumulativeWaterG: $0.targetCumulativeWaterG, instruction: $0.instruction)
      })
  }

  /// A new recipe made from `recipe` as the setup page shows it at `doseG`: weights scaled
  /// (in the instructions too), times stretched and the batch tuning's temperature, the way
  /// the timer would run it. Saving it never touches the original.
  func draft(
    from recipe: Recipe, scaledTo doseG: Double, tuning: BrewSizeAI.Tuning?, name: String
  ) -> RecipeDraft {
    var draft = self.draft(from: recipe, asCopy: true)
    draft.name = name
    guard let scaled = try? RecipeScaler.scale(recipe.scalable, toDose: doseG).recipe else {
      return draft
    }
    let factor = recipe.timingFactor(doseG: doseG, tuning: tuning)
    let weightFactor = recipe.doseG > 0 ? scaled.doseG / recipe.doseG : 1
    draft.doseG = scaled.doseG
    draft.waterG = scaled.waterG
    draft.iceG = scaled.iceG
    draft.tempC = tuning?.tempC ?? recipe.tempC
    draft.totalTimeS = recipe.totalTimeS.map { RecipeTiming.scaled($0, by: factor) }
    for index in draft.steps.indices {
      draft.steps[index].startOffsetS = RecipeTiming.scaled(
        draft.steps[index].startOffsetS, by: factor)
      draft.steps[index].instruction = TimerPlanBuilder.scaledWeights(
        in: draft.steps[index].instruction, by: weightFactor)
      if index < scaled.steps.count {
        draft.steps[index].targetCumulativeWaterG = scaled.steps[index].targetCumulativeWaterG
      }
    }
    return draft
  }

  /// Checks a draft without touching the store.
  static func validate(_ draft: RecipeDraft) -> RecipeEditorError? {
    if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .emptyName }
    guard draft.doseG.isFinite, draft.doseG > 0 else { return .invalidDose }
    guard draft.waterG.isFinite, draft.waterG > 0 else { return .invalidWater }
    if draft.includesIce, (draft.iceG ?? 0) <= 0 { return .invalidIce }
    let total = draft.waterG + (draft.includesIce ? (draft.iceG ?? 0) : 0)
    var lastTarget = 0.0
    for (index, step) in sorted(draft.steps).enumerated() {
      if step.startOffsetS < 0 { return .negativeTime(step: index + 1) }
      guard let target = step.targetCumulativeWaterG else { continue }
      if target < lastTarget - 0.0001 { return .targetGoesBackwards(step: index + 1) }
      if target > total + 0.5 { return .targetExceedsWater(step: index + 1) }
      lastTarget = target
    }
    return nil
  }

  /// Steps in time order; equal times keep the order the user arranged them in.
  static func sorted(_ steps: [RecipeStepDraft]) -> [RecipeStepDraft] {
    steps.enumerated().sorted {
      ($0.element.startOffsetS, $0.offset) < ($1.element.startOffsetS, $1.offset)
    }
    .map(\.element)
  }

  func save(_ draft: RecipeDraft) -> Result<Recipe, RecipeEditorError> {
    if let problem = Self.validate(draft) { return .failure(problem) }
    let recipe: Recipe
    if let sourceID = draft.sourceID {
      guard let existing = try? store.find(Recipe.self, id: sourceID) else {
        return .failure(.notFound)
      }
      recipe = existing
      for step in recipe.steps ?? [] { context.delete(step) }
    } else {
      recipe = Recipe()
      context.insert(recipe)
    }
    apply(draft, to: recipe)
    switch store.save() {
    case .success:
      return .success(recipe)
    case .failure(.saveFailed(let reason)):
      context.rollback()
      return .failure(.saveFailed(reason))
    }
  }

  private func apply(_ draft: RecipeDraft, to recipe: Recipe) {
    recipe.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    recipe.method = draft.methodID.flatMap { try? store.find(BrewMethod.self, id: $0) }
    recipe.credit = Self.cleaned(draft.credit)
    recipe.creditURL = draft.creditURL
    recipe.doseG = draft.doseG
    recipe.waterG = draft.waterG
    recipe.tempC = draft.tempC
    recipe.totalTimeS = draft.totalTimeS
    recipe.tuningNote = Self.cleaned(draft.tuningNote)
    recipe.includesIce = draft.includesIce
    recipe.iceG = draft.includesIce ? draft.iceG : nil
    recipe.updatedAt = Date()
    recipe.steps = Self.sorted(draft.steps).enumerated().map { index, step in
      let model = RecipeStep(order: index, kind: step.kind, startOffsetS: step.startOffsetS)
      model.targetCumulativeWaterG = step.targetCumulativeWaterG
      model.instruction = step.instruction.trimmingCharacters(in: .whitespacesAndNewlines)
      return model
    }
  }

  private static func cleaned(_ text: String?) -> String? {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty
    else { return nil }
    return trimmed
  }
}
