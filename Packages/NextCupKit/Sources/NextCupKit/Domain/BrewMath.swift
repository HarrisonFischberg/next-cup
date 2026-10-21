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

  /// "1:16.7" style label, one decimal place; `nil` when the ratio is unknown.
  public static func ratioLabel(_ ratio: Double?) -> String? {
    guard let ratio else { return nil }
    let tenths = (ratio * 10).rounded() / 10
    return "1:\(tenths)"
  }
}
