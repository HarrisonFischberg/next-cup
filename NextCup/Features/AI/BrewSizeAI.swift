import Foundation
import NextCupKit

/// "How much coffee?" on the Start brew page: once the dose is scaled to the amount, the
/// chosen AI suggests the temperature, total time and grind change for that batch size.
/// The provider in Settings → AI answers; with no key it falls to Apple's on-device model,
/// and with neither the recipe's own timing rule stays. Apple's model runs as the wheel
/// settles, because nothing leaves the iPhone; a keyed provider waits for a tap.
@MainActor
enum BrewSizeAI {
  struct Tuning: Equatable {
    var tempC: Double
    var totalTimeS: Int
    var grind: String
    var note: String
    /// Who answered, for the card: "Anthropic", "OpenAI" or "On this iPhone".
    var source: String
  }

  static let schema = JSONSchema.object([
    "tempC": .number,
    "totalTimeS": .integer,
    "grind": .string(allowed: ["much finer", "finer", "same", "coarser", "much coarser"]),
    "note": .string(),
  ])

  private static let system = """
    You are a careful specialty coffee barista. A recipe has been scaled to a new batch \
    size by dose; water already follows the ratio. Adjust only what a bigger or smaller \
    batch changes: water temperature in °C, total brew time in seconds (bigger beds drain \
    slower; keep steep recipes' steep time unless the batch changes a lot), and the grind \
    relative to the recipe's. Keep changes modest. The note is one short sentence on why.
    """

  /// True when some model can answer: a keyed provider in use, or Apple's on-device model.
  static var isAvailable: Bool { DirectAI.route != nil }

  /// The provider that would answer, when it is a keyed cloud provider; nil for Apple's model.
  /// The page asks for a tap before anything goes to it.
  static var cloudProviderTitle: String? { DirectAI.cloudProviderTitle }

  static func payload(
    recipe: String, method: String?, recipeDoseG: Double, doseG: Double, waterG: Double,
    yieldG: Double, tempC: Double?, totalTimeS: Int?
  ) -> AIRequestPayload {
    let lines = [
      "Recipe: \(recipe)" + (method.map { " on a \($0)" } ?? ""),
      "Recipe dose: \(Int(recipeDoseG.rounded())) g, temperature: "
        + (tempC.map { "\(Int($0.rounded())) °C" } ?? "not set")
        + ", total time: " + (totalTimeS.map { "\($0) s" } ?? "not set"),
      "New dose: \(String(format: "%.1f", doseG)) g, water: \(Int(waterG.rounded())) g, "
        + "finished coffee wanted: \(Int(yieldG.rounded())) g",
    ]
    return AIRequestPayload(
      system: system, userText: lines.joined(separator: "\n"), schemaName: "brew_size",
      schema: schema)
  }

  static func tune(_ payload: AIRequestPayload) async throws -> Tuning {
    let (answer, source) = try await DirectAI.send(payload)
    guard let tuning = parse(answer, source: source) else { throw AIError.invalidResponse }
    return tuning
  }

  /// Keeps an answer only inside sane brewing bounds.
  static func parse(_ answer: [String: Any], source: String) -> Tuning? {
    guard let temp = (answer["tempC"] as? NSNumber)?.doubleValue, (70...100).contains(temp),
      let time = (answer["totalTimeS"] as? NSNumber)?.intValue, (15...3_600).contains(time),
      let grind = answer["grind"] as? String
    else { return nil }
    return Tuning(
      tempC: temp.rounded(), totalTimeS: time, grind: grind,
      note: (answer["note"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
      source: source)
  }
}
