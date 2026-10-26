/// How step times follow the dose. Water targets always scale with the dose; times only
/// partly do. Pouring takes longer the more water goes through a dripper, so pour-over
/// timing stretches gently (the square root of the dose ratio, kept between 0.75 and 1.6).
/// Steeping, espresso and cold brew times depend on grind and temperature, not dose, so
/// they stay as written.
public enum RecipeTiming {
  public static func factor(isPourOver: Bool, recipeDoseG: Double, doseG: Double) -> Double {
    guard isPourOver, recipeDoseG > 0, doseG > 0 else { return 1 }
    return min(1.6, max(0.75, (doseG / recipeDoseG).squareRoot()))
  }

  /// A time in seconds at this factor, to the nearest 5 seconds.
  public static func scaled(_ seconds: Int, by factor: Double) -> Int {
    guard factor != 1 else { return seconds }
    return Int((Double(seconds) * factor / 5).rounded()) * 5
  }
}
