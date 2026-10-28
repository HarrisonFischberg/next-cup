import Foundation
import NextCupKit

/// "How much coffee?" on the Start brew page: once the dose is scaled to the amount, the
/// chosen AI suggests the temperature, total time and grind change for that batch size.
/// The provider in Settings → AI answers; with no key it falls to Apple's on-device model,
/// and with neither the recipe's own timing rule stays.
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
  static var isAvailable: Bool { route != nil }

  private static var route: (AIProvider, String)? {
    let preferences = AIPreferences()
    if let provider = preferences.provider(for: .diagnosis), provider.kind != nil,
      let model = preferences.modelID(for: .diagnosis), KeychainStore().hasKey(for: provider),
      preferences.hasAcceptedDisclosure(for: provider)
    {
      return (provider, model)
    }
    return AppleIntelligence.isAvailable ? (.apple, AppleIntelligence.modelID) : nil
  }

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
    guard let (provider, model) = route else { throw AIError.unavailable(nil) }
    let result: AIResult
    if let kind = provider.kind {
      let keychain = KeychainStore()
      let client = AIClient(
        transport: URLSessionTransport(),
        key: { _ in (try? keychain.key(for: provider)) ?? nil },
        disclosureAccepted: { _ in true })
      result = try await client.send(
        payload, provider: kind, model: model, effort: AIPreferences().effort)
    } else {
      result = try await AppleIntelligence.send(payload)
    }
    guard let answer = try JSONSerialization.jsonObject(with: result.json) as? [String: Any],
      let tuning = parse(answer, source: provider == .apple ? "On this iPhone" : provider.title)
    else { throw AIError.invalidResponse }
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
