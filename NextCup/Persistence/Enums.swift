import Foundation

/// Stored enums for the SwiftData schema. Raw values are persisted and exported,
/// so renaming a case is a schema migration.

enum Verdict: String, Codable, CaseIterable, Sendable {
  case sour, bitter, weak, strong, balanced
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
