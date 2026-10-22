import Foundation
import NextCupKit

/// Display strings for recipes. Storage is grams and °C; conversion happens here
/// through `UnitPreferences` (X8). The units setting itself arrives in T020, so
/// until then the preferences come from two `UserDefaults` keys that default to
/// grams and °C.
enum UnitStorage {
  static let weightKey = "units.weight"
  static let temperatureKey = "units.temperature"

  static func preferences(_ defaults: UserDefaults = .standard) -> UnitPreferences {
    UnitPreferences(
      weight: defaults.string(forKey: weightKey).flatMap(WeightUnit.init(rawValue:)) ?? .grams,
      temperature: defaults.string(forKey: temperatureKey).flatMap(TemperatureUnit.init(rawValue:))
        ?? .celsius)
  }
}

enum RecipeFormat {
  /// "3:05" for 185 seconds.
  static func clock(_ seconds: Int) -> String {
    let safe = max(seconds, 0)
    return String(format: "%d:%02d", safe / 60, safe % 60)
  }

  /// "1 min 5 s" style words for VoiceOver.
  static func spokenTime(_ seconds: Int) -> String {
    let safe = max(seconds, 0)
    let minutes = safe / 60
    let rest = safe % 60
    switch (minutes, rest) {
    case (0, _): return "\(rest) seconds"
    case (_, 0): return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    default: return "\(minutes) min \(rest) seconds"
    }
  }

  /// Weight in the user's unit: whole grams, one decimal ounce.
  static func weight(_ grams: Double, _ units: UnitPreferences, withSymbol: Bool = true) -> String {
    let value = units.displayWeight(grams: grams)
    let text =
      units.weight == .grams
      ? (value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value))
      : String(format: "%.2f", value)
    return withSymbol ? "\(text) \(units.weightSymbol)" : text
  }

  static func temperature(_ celsius: Double, _ units: UnitPreferences) -> String {
    String(format: "%.0f%@", units.displayTemperature(celsius: celsius), units.temperatureSymbol)
  }

  static func title(_ kind: StepKind) -> String {
    switch kind {
    case .bloom: "Bloom"
    case .pour: "Pour"
    case .wait: "Wait"
    case .stir: "Stir"
    case .swirl: "Swirl"
    case .invert: "Invert"
    case .press: "Press"
    case .plug: "Plug"
    case .bypass: "Bypass"
    case .openValve: "Open valve"
    case .closeValve: "Close valve"
    case .drawdown: "Drawdown"
    }
  }

  static func title(_ style: BrewStyle) -> String {
    switch style {
    case .pourOver: "Pour over"
    case .immersion: "Immersion"
    case .espresso: "Espresso"
    case .cold: "Cold"
    }
  }

  /// VoiceOver reads each step as "kind, time, target".
  static func spokenStep(
    kind: StepKind, startOffsetS: Int, targetG: Double?, units: UnitPreferences
  )
    -> String
  {
    var parts = [title(kind), "at " + spokenTime(startOffsetS)]
    if let targetG {
      let spokenUnit = units.weight == .grams ? "grams" : "ounces"
      parts.append("target \(weight(targetG, units, withSymbol: false)) \(spokenUnit)")
    }
    return parts.joined(separator: ", ")
  }

  /// Recipes group by the style of their method; a recipe without a method goes last.
  static func groupTitle(for recipe: Recipe) -> String {
    recipe.method.map { title($0.style) } ?? "Other"
  }

  static func groupOrder(for recipe: Recipe) -> Int {
    guard let style = recipe.method?.style else { return BrewStyle.allCases.count }
    return BrewStyle.allCases.firstIndex(of: style) ?? BrewStyle.allCases.count
  }
}

extension Recipe {
  /// Steps in timeline order.
  var orderedSteps: [RecipeStep] {
    (steps ?? []).sorted { ($0.order, $0.startOffsetS) < ($1.order, $1.startOffsetS) }
  }

  var scalable: ScalableRecipe {
    ScalableRecipe(
      doseG: doseG, waterG: waterG, iceG: iceG, includesIce: includesIce,
      steps: orderedSteps.map {
        ScalableStep(
          order: $0.order, startOffsetS: $0.startOffsetS,
          targetCumulativeWaterG: $0.targetCumulativeWaterG)
      })
  }
}
