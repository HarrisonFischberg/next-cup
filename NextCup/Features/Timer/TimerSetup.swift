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
  /// Each step's kind (StepKind raw value) by the step's `order`.
  var stepKinds: [String] = []
  /// The built-in method's key (or its style for one the user made), so the timer
  /// words each step the way that brewer is used.
  var methodKey: String?
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

  /// Builds the plan for a recipe at `doseG`. Water targets scale with the dose and
  /// pour-over times stretch gently; an AI tuning for the batch sets the temperature and
  /// stretches every step to its total time instead.
  static func setup(
    for recipe: Recipe, doseG: Double, tuning: BrewSizeAI.Tuning? = nil
  ) throws -> TimerSetup {
    let scaled = try RecipeScaler.scale(recipe.scalable, toDose: doseG).recipe
    let steps = recipe.orderedSteps
    let factor = recipe.timingFactor(doseG: doseG, tuning: tuning)
    let weightFactor = recipe.doseG > 0 ? scaled.doseG / recipe.doseG : 1
    let timerSteps = steps.enumerated().map { index, step in
      TimerStep(
        order: index, label: RecipeFormat.title(step.kind),
        instruction: scaledWeights(in: step.instruction, by: weightFactor),
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
      tempC: tuning?.tempC ?? recipe.tempC, scaled: scaled,
      stepKinds: steps.map(\.kind.rawValue),
      methodKey: recipe.method?.builtInKey ?? recipe.method?.style.rawValue)
  }

  /// Gram amounts written in a step ("Pour to 500 g") follow the batch, like its target:
  /// every weight in a recipe scales with the dose.
  static func scaledWeights(in text: String, by factor: Double) -> String {
    guard abs(factor - 1) > 0.001 else { return text }
    return text.replacing(/(\d+(?:\.\d+)?)(\s?)g\b/) { match in
      let grams = (Double(match.output.1) ?? 0) * factor
      return "\(Int(grams.rounded()))\(match.output.2)g"
    }
  }
}

extension Recipe {
  /// Pour-over times stretch gently with the dose; steeps, espresso and cold brew keep theirs.
  /// A tuning's total time wins when the recipe has one to measure it against.
  func timingFactor(doseG: Double, tuning: BrewSizeAI.Tuning? = nil) -> Double {
    if let tuning, let total = totalTimeS, total > 0 {
      return Double(tuning.totalTimeS) / Double(total)
    }
    return RecipeTiming.factor(
      isPourOver: method?.style == .pourOver, recipeDoseG: self.doseG, doseG: doseG)
  }
}
