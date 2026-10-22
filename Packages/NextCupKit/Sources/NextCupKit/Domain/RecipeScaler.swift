/// One timeline step as the scaler sees it.
public struct ScalableStep: Equatable, Sendable {
  public var order: Int
  public var startOffsetS: Int
  public var targetCumulativeWaterG: Double?

  public init(order: Int, startOffsetS: Int, targetCumulativeWaterG: Double?) {
    self.order = order
    self.startOffsetS = startOffsetS
    self.targetCumulativeWaterG = targetCumulativeWaterG
  }
}

/// A recipe reduced to the numbers that scale with dose.
/// On an iced recipe `waterG` is the hot water and `iceG` is separate.
public struct ScalableRecipe: Equatable, Sendable {
  public var doseG: Double
  public var waterG: Double
  public var iceG: Double?
  public var includesIce: Bool
  public var steps: [ScalableStep]

  public init(
    doseG: Double, waterG: Double, iceG: Double? = nil, includesIce: Bool = false,
    steps: [ScalableStep] = []
  ) {
    self.doseG = doseG
    self.waterG = waterG
    self.iceG = iceG
    self.includesIce = includesIce
    self.steps = steps
  }

  /// Hot water plus ice when the recipe is iced.
  public var totalWaterG: Double {
    waterG + (includesIce ? max(iceG ?? 0, 0) : 0)
  }
}

public enum RecipeScalerError: Error, Equatable, Sendable {
  case invalidDose
  case invalidRecipeDose
}

public struct ScaledRecipe: Equatable, Sendable {
  public var recipe: ScalableRecipe
  public var factor: Double
  /// Plain-language notes about rounding, ready to show under the targets.
  public var notes: [String]
}

public enum RecipeScaler {
  /// Scales dose, water, ice and every step target by `newDose ÷ recipe.doseG`.
  /// Water and ice round to whole grams, dose to 0.1 g; step offsets (time) never change.
  public static func scale(_ recipe: ScalableRecipe, toDose newDose: Double) throws -> ScaledRecipe
  {
    guard newDose.isFinite, newDose > 0 else { throw RecipeScalerError.invalidDose }
    guard recipe.doseG > 0 else { throw RecipeScalerError.invalidRecipeDose }

    let factor = newDose / recipe.doseG
    var largestShift = 0.0

    func grams(_ exact: Double) -> Double {
      let rounded = exact.rounded()
      largestShift = max(largestShift, abs(rounded - exact))
      return rounded
    }

    var scaled = recipe
    scaled.doseG = (newDose * 10).rounded() / 10
    scaled.waterG = grams(recipe.waterG * factor)
    scaled.iceG = recipe.iceG.map { grams($0 * factor) }
    scaled.steps = recipe.steps.map { step in
      var copy = step
      copy.targetCumulativeWaterG = step.targetCumulativeWaterG.map { grams($0 * factor) }
      return copy
    }

    var notes: [String] = []
    if largestShift > 0.0001 {
      let shift = (largestShift * 10).rounded() / 10
      notes.append("Water targets are rounded to whole grams (up to \(shift) g off).")
    }
    if scaled.doseG != newDose {
      notes.append("Dose is rounded to 0.1 g.")
    }
    return ScaledRecipe(recipe: scaled, factor: factor, notes: notes)
  }
}
