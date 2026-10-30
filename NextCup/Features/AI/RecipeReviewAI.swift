import Foundation
import NextCupKit

/// "Improve with AI" in the recipe editor: after the user adds or changes steps, the AI in
/// Settings → AI reads the recipe (and what it has to work around, such as a cone that holds
/// less than the recipe pours) and suggests better steps. Nothing changes until the user
/// picks "Use these steps", and the editor's Save is still needed after that. A keyed
/// provider is asked only on the tap; Apple's on-device model keeps it on the iPhone.
@MainActor
enum RecipeReviewAI {
  struct Change: Equatable, Hashable {
    var what: String
    var why: String
  }

  struct Review: Equatable, Identifiable {
    var id = UUID()
    var summary: String
    var changes: [Change]
    /// nil keeps the recipe's own.
    var tempC: Double?
    var totalTimeS: Int?
    var steps: [RecipeStepDraft]
    /// Who answered: "Anthropic", "OpenAI" or "On this iPhone".
    var source: String
  }

  /// Steps that put water on the scale; every other kind carries no target.
  static let pouringKinds: Set<StepKind> = [.bloom, .pour, .bypass]
  static let maxSteps = 30

  static let schema = JSONSchema.object([
    "summary": .string(),
    "changes": .array(.object(["what": .string(), "why": .string()])),
    "tempC": .number,
    "totalTimeS": .integer,
    "steps": .array(
      .object([
        "kind": .string(allowed: StepKind.allCases.map(\.rawValue)),
        "atS": .integer,
        "waterG": .number,
        "instruction": .string(),
      ])),
  ])

  private static let system = """
    You are a careful specialty coffee barista reviewing a home brewer's recipe. They may \
    have added or changed steps to suit their own gear, and their note says what they need \
    to work around. Keep the dose and the total water exactly as given. Keep their changes \
    when they work, and change only what would make the cup worse or the steps hard to \
    follow: a pour bigger than the brewer holds, no time left to drain, a missing bloom or \
    stir, a temperature wrong for the method. Return the whole recipe's steps in time order. \
    atS is the second the step starts. waterG is the running total on the scale after a \
    bloom, pour or bypass step, and 0 for every other step. closeValve and openValve are for \
    switchable drippers; heat, offHeat and brew are for stovetop and machines. Each \
    instruction is one short plain sentence. tempC is the water temperature in °C (0 when \
    the recipe has none). totalTimeS is the second the cup is done. changes lists each \
    change you made, as what (a few words) and why (one sentence); leave it empty when the \
    recipe is already sound. summary is one or two plain sentences.
    """

  static var isAvailable: Bool { DirectAI.route != nil }
  /// Who the tap sends the recipe to; nil when Apple's model answers on the iPhone.
  static var cloudProviderTitle: String? { DirectAI.cloudProviderTitle }

  /// The recipe as text: brewer, numbers, the user's note and every step. No photo, no
  /// beans, no brews.
  static func payload(_ draft: RecipeDraft, methodName: String?, note: String)
    -> AIRequestPayload
  {
    var lines = [
      "Recipe: \(draft.name)" + (methodName.map { " on a \($0)" } ?? ""),
      "Dose: \(grams(draft.doseG)) g, total water: \(grams(draft.waterG)) g"
        + (draft.includesIce ? ", ice: \(grams(draft.iceG ?? 0)) g" : "")
        + ", temperature: " + (draft.tempC.map { "\(Int($0.rounded())) °C" } ?? "not set")
        + ", total time: " + (draft.totalTimeS.map { "\($0) s" } ?? "not set"),
    ]
    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { lines.append("Their note: \(trimmed)") }
    lines.append("Steps:")
    for (index, step) in RecipeEditorService.sorted(draft.steps).enumerated() {
      var line = "\(index + 1). at \(step.startOffsetS) s, \(step.kind.rawValue)"
      if let target = step.targetCumulativeWaterG { line += ", to \(grams(target)) g" }
      if !step.instruction.isEmpty { line += ": \(step.instruction)" }
      lines.append(line)
    }
    return AIRequestPayload(
      system: system, userText: lines.joined(separator: "\n"), schemaName: "recipe_review",
      schema: schema)
  }

  static func review(_ payload: AIRequestPayload, base: RecipeDraft) async throws -> Review {
    let (answer, source) = try await DirectAI.send(payload)
    guard let review = parse(answer, base: base, source: source) else {
      throw AIError.invalidResponse
    }
    return review
  }

  /// Keeps an answer only when its steps make a recipe the editor itself would save, at the
  /// same dose and water. Water on a step that pours nothing is dropped.
  static func parse(_ answer: [String: Any], base: RecipeDraft, source: String) -> Review? {
    guard let rawSteps = answer["steps"] as? [[String: Any]],
      (1...maxSteps).contains(rawSteps.count)
    else { return nil }
    var steps: [RecipeStepDraft] = []
    for raw in rawSteps {
      guard let kind = (raw["kind"] as? String).flatMap(StepKind.init(rawValue:)),
        let at = (raw["atS"] as? NSNumber)?.intValue, (0...86_400).contains(at)
      else { return nil }
      let water = (raw["waterG"] as? NSNumber)?.doubleValue ?? 0
      let instruction = (raw["instruction"] as? String ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      steps.append(
        RecipeStepDraft(
          kind: kind, startOffsetS: at,
          targetCumulativeWaterG: pouringKinds.contains(kind) && water > 0
            ? water.rounded() : nil,
          instruction: String(instruction.prefix(300))))
    }
    let temp = (answer["tempC"] as? NSNumber)?.doubleValue ?? 0
    let time = (answer["totalTimeS"] as? NSNumber)?.intValue ?? 0
    var check = base
    check.steps = steps
    check.tempC = (1...100).contains(temp) ? temp.rounded() : base.tempC
    check.totalTimeS = (10...86_400).contains(time) ? time : base.totalTimeS
    guard RecipeEditorService.validate(check) == nil else { return nil }
    let changes = (answer["changes"] as? [[String: Any]] ?? []).compactMap { raw -> Change? in
      let what = (raw["what"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      guard !what.isEmpty else { return nil }
      return Change(
        what: what,
        why: (raw["why"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return Review(
      summary: (answer["summary"] as? String ?? "").trimmingCharacters(
        in: .whitespacesAndNewlines),
      changes: changes, tempC: check.tempC, totalTimeS: check.totalTimeS,
      steps: RecipeEditorService.sorted(steps), source: source)
  }

  private static func grams(_ value: Double) -> String {
    value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
  }
}
