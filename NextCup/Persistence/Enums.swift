import Foundation

/// Stored enums for the SwiftData schema. Raw values are persisted and exported,
/// so renaming a case is a schema migration.

enum Verdict: String, Codable, CaseIterable, Sendable {
  case sour, bitter, weak, bright, strong, balanced

  /// The draft keeps several tastes in its one field, comma-separated ("sour,weak"), so a
  /// single taste saved before reads the same.
  static func picked(_ raw: String?) -> [Verdict] {
    (raw ?? "").split(separator: ",").compactMap { Verdict(rawValue: String($0)) }
  }

  static func joined(_ verdicts: [Verdict]) -> String? {
    verdicts.isEmpty ? nil : verdicts.map(\.rawValue).joined(separator: ",")
  }

  /// Picking or unpicking one taste. Any tastes can go together, Balanced included.
  static func toggled(_ option: Verdict, in raw: String?) -> String? {
    var tastes = picked(raw)
    if let index = tastes.firstIndex(of: option) {
      tastes.remove(at: index)
    } else {
      tastes.append(option)
    }
    return joined(tastes)
  }
}

enum RoastLevel: String, Codable, CaseIterable, Sendable {
  case ultraLight, light, mediumLight, medium, mediumDark, dark
}

enum BeanStatus: String, Codable, CaseIterable, Sendable {
  case inUse, buyAgain, wishlist, finished
}

enum BrewStyle: String, Codable, CaseIterable, Sendable {
  case pourOver, immersion, espresso, cold
}

enum BrewParameter: String, Codable, CaseIterable, Sendable {
  case dose, water, yield, grind, temperature, time, tds, rating, notes, photo
}

enum StepKind: String, Codable, CaseIterable, Sendable {
  case bloom, pour, wait, stir, swirl, invert, press, plug, bypass
  case openValve, closeValve, drawdown
  /// Stovetop and machine steps (moka pot, drip machine).
  case heat, offHeat, brew
}

enum SuggestionSource: String, Codable, CaseIterable, Sendable {
  case rules, ai
}

enum SuggestionState: String, Codable, CaseIterable, Sendable {
  case proposed, accepted, edited, dismissed
}

enum AIFeature: String, Codable, CaseIterable, Sendable {
  case diagnosis, photoInterpretation, bagRecognition, insights, paperImport
}

enum AIProvider: String, Codable, CaseIterable, Sendable {
  case anthropic, openAI
  /// Apple's on-device model: no key, nothing leaves the iPhone.
  case apple
}

enum AIRequestStatus: String, Codable, CaseIterable, Sendable {
  case queued, sending, done, failed, cancelled
}

enum TaxonomyDimension: String, Codable, CaseIterable, Sendable {
  case origin, process, roast, flavor, brewer
}
