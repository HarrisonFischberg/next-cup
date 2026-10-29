/// Derived brew numbers. Missing or non-positive inputs give `nil`, never 0.
public enum BrewMath {
  /// Water ÷ dose. On an iced recipe the ice counts toward water.
  public static func ratio(doseG: Double?, waterG: Double?, iceG: Double? = nil) -> Double? {
    guard let doseG, let waterG, doseG > 0, waterG > 0 else { return nil }
    let total = waterG + max(iceG ?? 0, 0)
    return total / doseG
  }

  /// Yield ÷ dose for espresso.
  public static func espressoRatio(doseG: Double?, yieldG: Double?) -> Double? {
    guard let doseG, let yieldG, doseG > 0, yieldG > 0 else { return nil }
    return yieldG / doseG
  }

  /// Extraction yield in percent: TDS percent × beverage weight ÷ dose.
  public static func extractionYield(tds: Double?, beverageG: Double?, doseG: Double?) -> Double? {
    guard let tds, let beverageG, let doseG, tds > 0, beverageG > 0, doseG > 0 else { return nil }
    return tds * beverageG / doseG
  }

  /// Grams of water each gram of grounds keeps.
  public static let absorption = 2.0

  /// The dose that makes `yieldG` of finished coffee at this recipe's ratio: the grounds
  /// keep about 2 g of water per gram, so a cup is the water (and ice) less that. At an
  /// espresso-like ratio (4 or under) the recipe's water already is the drink.
  public static func dose(forYieldG yieldG: Double, ratio: Double?) -> Double? {
    guard let ratio, ratio > 0, yieldG > 0 else { return nil }
    return yieldG / (ratio > 4 ? ratio - absorption : ratio)
  }

  /// What reaches the cup from `waterG` poured on `doseG`: the inverse of `dose(forYieldG:)`.
  public static func cupG(waterG: Double, doseG: Double) -> Double? {
    guard waterG > 0, doseG > 0 else { return nil }
    return waterG / doseG > 4 ? waterG - absorption * doseG : waterG
  }

  /// "1:16.7" style label, one decimal place; `nil` when the ratio is unknown.
  public static func ratioLabel(_ ratio: Double?) -> String? {
    guard let ratio else { return nil }
    let tenths = (ratio * 10).rounded() / 10
    return "1:\(tenths)"
  }
}
