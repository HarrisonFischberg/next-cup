import Foundation
import NextCupKit

/// Everything the guided timer needs for one run: the plan, the scaled numbers it
/// shows, and enough of the recipe to prefill the brew form at the end.
struct TimerSetup: Identifiable, Hashable {
  let id = UUID()
  let plan: TimerPlan
  let recipeID: UUID
  let recipeName: String
  let methodName: String?
  let tempC: Double?
  /// The recipe after scaling to the dose the user chose.
  let scaled: ScalableRecipe
  /// Display names for each step, in plan order.
  let stepTitles: [String]
  /// Chosen on the Start brew page and carried into the brew form.
  var beanID: UUID?
  var beanName: String?
  var grinderID: UUID?
  var grindSetting = ""

  static func == (lhs: TimerSetup, rhs: TimerSetup) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }

  /// The brew form values for a finished run: recipe numbers, with the time the
  /// timer actually reached.
  func seed(elapsedS: Double, endedEarly: Bool) -> BrewFormSeed {
    BrewFormSeed(
      sessionKey: id.uuidString, recipeID: recipeID, recipeName: recipeName,
      methodName: methodName, doseG: scaled.doseG, waterG: scaled.waterG, tempC: tempC,
      totalTimeS: Int(elapsedS.rounded()), targetTimeS: plan.totalDurationS,
      endedEarly: endedEarly, beanID: beanID, beanName: beanName, grinderID: grinderID,
      grindSetting: grindSetting)
  }
}

enum TimerPlanBuilder {
  /// Seconds the brew runs after the last step when the recipe gives no total time.
  static let tailS = 30

  /// Builds the plan for a recipe at `doseG`. Step times never change with dose;
  /// water targets scale with it.
  static func setup(for recipe: Recipe, doseG: Double) throws -> TimerSetup {
    let scaled = try RecipeScaler.scale(recipe.scalable, toDose: doseG).recipe
    let steps = recipe.orderedSteps
    let factor = recipe.timingFactor(doseG: doseG)
    let timerSteps = steps.enumerated().map { index, step in
      TimerStep(
        order: index, label: RecipeFormat.title(step.kind), instruction: step.instruction,
        startOffsetS: RecipeTiming.scaled(step.startOffsetS, by: factor),
        targetCumulativeWaterG: index < scaled.steps.count
          ? scaled.steps[index].targetCumulativeWaterG : nil)
    }
    let lastOffset = timerSteps.map(\.startOffsetS).max() ?? 0
    let declared = RecipeTiming.scaled(recipe.totalTimeS ?? 0, by: factor)
    let total = declared > lastOffset ? declared : lastOffset + tailS
    let plan = try TimerPlan(steps: timerSteps, totalDurationS: total)
    return TimerSetup(
      plan: plan, recipeID: recipe.id, recipeName: recipe.name, methodName: recipe.method?.name,
      tempC: recipe.tempC, scaled: scaled, stepTitles: timerSteps.map(\.label))
  }
}

extension Recipe {
  /// Pour-over times stretch gently with the dose; steeps, espresso and cold brew keep theirs.
  func timingFactor(doseG: Double) -> Double {
    RecipeTiming.factor(
      isPourOver: method?.style == .pourOver, recipeDoseG: self.doseG, doseG: doseG)
  }
}
