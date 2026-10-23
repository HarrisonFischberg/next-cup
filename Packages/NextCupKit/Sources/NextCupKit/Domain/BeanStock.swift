import Foundation

public enum StockLevel: Equatable, Sendable {
  /// No bag weight was entered, so nothing can be worked out.
  case unknown
  case ok
  case low
  case empty
}

/// How much of a bag is left: the bag weight, minus every brew that used it, plus
/// the owner's manual correction (a spill, a gift, a bag weighed on a scale).
/// Derived on demand and never stored (blueprint §2).
public enum BeanStock {
  /// A bag at or below this share of its weight counts as running low.
  public static let lowShare = 0.2

  /// Grams left, never below zero. `nil` without a bag weight: an unknown amount
  /// is not zero.
  public static func remainingG(
    bagWeightG: Double?, usedG: [Double], adjustmentG: Double = 0
  ) -> Double? {
    guard let bagWeightG, bagWeightG > 0 else { return nil }
    let used = usedG.reduce(0, +)
    return max(0, bagWeightG - used + adjustmentG)
  }

  /// The correction that makes the remaining amount equal `remainingG`, so a
  /// weighed bag overrides drift without rewriting any brew. `nil` without a bag
  /// weight or for a negative target.
  public static func adjustmentG(
    settingRemainingTo remainingG: Double, bagWeightG: Double?, usedG: [Double]
  ) -> Double? {
    guard let bagWeightG, bagWeightG > 0, remainingG >= 0 else { return nil }
    return remainingG - (bagWeightG - usedG.reduce(0, +))
  }

  public static func level(remainingG: Double?, bagWeightG: Double?) -> StockLevel {
    guard let remainingG, let bagWeightG, bagWeightG > 0 else { return .unknown }
    if remainingG <= 0 { return .empty }
    return remainingG <= bagWeightG * lowShare ? .low : .ok
  }
}
