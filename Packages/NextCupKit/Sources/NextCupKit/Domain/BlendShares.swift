import Foundation

/// Splits a brew's dose between the beans in a blend. Each bean has a number of
/// parts (1 part each is an even split), and every bean is charged its share of
/// the dose, so a blend brew deducts from each bag.
public enum BlendShares {
  /// Grams per bean, in the order of `parts`, summing to `dose` (to 0.01 g).
  /// Non-positive or missing parts count as zero; if every part is zero the dose
  /// is split evenly. An empty list or a dose of zero or less gives all zeros.
  public static func grams(dose: Double, parts: [Double]) -> [Double] {
    guard !parts.isEmpty, dose > 0 else { return parts.map { _ in 0 } }
    let cleaned = parts.map { $0.isFinite && $0 > 0 ? $0 : 0 }
    let total = cleaned.reduce(0, +)
    let weights = total > 0 ? cleaned : parts.map { _ in 1.0 }
    let weightTotal = weights.reduce(0, +)

    var result = weights.map { (dose * $0 / weightTotal * 100).rounded() / 100 }
    // Rounding can leave a hundredth of a gram over or under; the largest share
    // takes it so the beans always add up to the dose.
    let drift = ((dose - result.reduce(0, +)) * 100).rounded() / 100
    if drift != 0, let largest = result.indices.max(by: { result[$0] < result[$1] }) {
      result[largest] = max(0, ((result[largest] + drift) * 100).rounded() / 100)
    }
    return result
  }

  // MARK: Editing shares

  /// `parts` as percentages that add up to 100. Zero or invalid parts split evenly.
  public static func percentages(parts: [Double]) -> [Double] {
    guard !parts.isEmpty else { return [] }
    let cleaned = parts.map { $0.isFinite && $0 > 0 ? $0 : 0 }
    let total = cleaned.reduce(0, +)
    guard total > 0 else { return parts.map { _ in 100 / Double(parts.count) } }
    return cleaned.map { $0 / total * 100 }
  }

  /// Adds one more bean at an even share: the new bean takes `100 / (n + 1)` and
  /// the others give up the same proportion.
  public static func appending(to shares: [Double]) -> [Double] {
    let current = percentages(parts: shares)
    let count = Double(current.count + 1)
    return current.map { $0 * (count - 1) / count } + [100 / count]
  }

  /// Takes the bean at `index` out and spreads its share across the others.
  public static func removing(at index: Int, from shares: [Double]) -> [Double] {
    guard shares.indices.contains(index) else { return percentages(parts: shares) }
    var rest = shares
    rest.remove(at: index)
    return percentages(parts: rest)
  }

  /// Sets one bean's share and scales the others to fill the rest, keeping their
  /// proportions. The share stays between 5% and 95% when there is more than one
  /// bean, so no bean is dropped by a tap on the stepper.
  public static func rebalanced(_ shares: [Double], setting index: Int, to percent: Double)
    -> [Double]
  {
    let current = percentages(parts: shares)
    guard current.count > 1, current.indices.contains(index) else { return current }
    let target = min(95, max(5, percent.isFinite ? percent : current[index]))
    let others = current.indices.filter { $0 != index }
    let othersTotal = others.reduce(0) { $0 + current[$1] }
    var result = current
    for other in others {
      result[other] =
        othersTotal > 0
        ? current[other] / othersTotal * (100 - target) : (100 - target) / Double(others.count)
    }
    result[index] = target
    return result
  }
}
