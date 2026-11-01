import Foundation
import NextCupKit

/// The recipe AI. "Improve with AI" in the recipe editor rewrites the user's recipe to
/// follow their note (a cone that holds 400 g, a hybrid steep then pour), and "Create with
/// AI" on the Brew tab writes a whole new recipe for a brewer from a note. Nothing is
/// stored until the user saves in the editor. A keyed provider is asked only on the tap;
/// Apple's on-device model keeps it on the iPhone.
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
    /// The whole recipe the AI proposes: name, numbers and steps.
    var draft: RecipeDraft
    /// Who answered: "Anthropic", "OpenAI" or "On this iPhone".
    var source: String
    /// Where to start on the user's grinder, in its own units; empty when none was named.
    var grind = ""
  }

  enum Mode { case improve, create }

  /// Steps that put water on the scale; every other kind carries no target.
  static let pouringKinds: Set<StepKind> = [.bloom, .pour, .bypass]
  static let maxSteps = 30

  static let schema = JSONSchema.object([
    "summary": .string(),
    "changes": .array(.object(["what": .string(), "why": .string()])),
    "name": .string(),
    "doseG": .number,
    "waterG": .number,
    "tempC": .number,
    "totalTimeS": .integer,
    "grind": .string(),
    "steps": .array(
      .object([
        "kind": .string(allowed: StepKind.allCases.map(\.rawValue)),
        "atS": .integer,
        "waterG": .number,
        "instruction": .string(),
      ])),
  ])

  /// How every answer is written, for both modes.
  static let format = """
    Return the whole recipe. doseG is the coffee in grams and waterG the total brew water in \
    grams. steps are in time order; atS is the second the step starts. Steps in the same \
    second are listed in the order they are done, so a closeValve comes before the water it \
    holds. A wait starts as soon as the step before it ends and lasts until the next step. A \
    step's waterG is the running total poured so far after a bloom, pour or bypass step, and \
    0 for every other step; the last pouring step's waterG equals the recipe's waterG. Step \
    kinds: bloom, pour, wait, stir, swirl, invert, press, plug, bypass, drawdown; closeValve \
    and openValve for switchable drippers; heat, offHeat and brew for stovetop and machines. \
    Each instruction is one specific sentence the brewer can follow (what to do, how much, \
    how long) for that step only, never just the step's name. tempC is the water temperature \
    in °C (0 for none). totalTimeS is the second the cup is done. grind is the setting to \
    start at on their grinder, written the way its dial reads with no units (for example \
    "22" or "1.5.0"). Start inside the guide's range for the brewer, but when their note \
    asks for a coarser or finer grind than usual, go past that end of the range as far as \
    it asks (very coarse sits near the coarsest setting), never past the grinder's own \
    settings. Empty when no grinder is named. summary is one or two plain sentences on how \
    the recipe works.
    """

  private static let improveSystem = """
    You are an expert specialty coffee barista rewriting a home brewer's recipe. Their note \
    comes first: when it names a total water or dose, what their brewer holds, or a \
    technique, rewrite the steps to do exactly that, adding, removing and retiming steps. \
    Never have more water in the brewer at once than the note says it holds: water still \
    in the brewer is what was poured minus what has drained, so split the pour, and open \
    the valve or let it drain before the next pour. A hybrid on a switchable dripper is: \
    close the valve, pour part of the water, stir, steep, open the valve to drain, then \
    pour the rest over in pulses with the valve open, then drawdown. Keep the dose and \
    total water unless the note asks for other amounts; then scale the dose to keep the \
    ratio unless it says otherwise. Without a note, fix only real problems. changes lists \
    each change, as what (a few words) and why (one sentence). Keep the recipe's name.
    """ + "\n" + format

  private static let createSystem = """
    You are an expert specialty coffee barista writing a new recipe for a home brewer on \
    the brewer named. Follow their note exactly: amounts, cup size, taste, the coffee and \
    any limit of their gear (never more water in the brewer at once than it holds). Use a \
    sound ratio and temperature for the brewer and roast. name is a short title of two to \
    four words. changes is an empty list. On a switchable dripper the first step is \
    closeValve unless the recipe starts open, and a valve step's instruction only works \
    the valve. When notes from coffee sites are given, base the numbers and steps on what \
    those sources agree on, then fit them to the note.
    """ + "\n" + format

  /// The web search before Create with AI, run only with a keyed provider.
  static let researchSystem = """
    You research coffee recipes for a home brewer. Search well-known specialty coffee \
    sites (for example beanbench.coffee and the brew guides of established roasters and \
    coffee educators) for popular, well-regarded recipes for the brewer named that fit \
    what they want. Answer in under 200 words: the dose, water, ratio, temperature, grind, \
    pour or steep schedule and timing the sources recommend, and where they disagree.
    """

  static var isAvailable: Bool { DirectAI.route != nil }
  /// Who the tap sends the recipe to; nil when Apple's model answers on the iPhone.
  static var cloudProviderTitle: String? { DirectAI.cloudProviderTitle }

  /// The grinder's name, plus its whole scale and the bundled guide's starting range for
  /// this brewer when the guide knows the grinder, so the AI's grind is grounded in real
  /// settings and a "very coarse" note can go past the usual range.
  static func grinderLine(_ grinder: String?, methodName: String?) -> String? {
    guard let name = grinder?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
    else { return nil }
    guard let guide = GrinderGuide.find(name), let finest = guide.settings.first,
      let coarsest = guide.settings.last
    else { return "Grinder: \(name)" }
    let scale = "settings run from \(finest) finest to \(coarsest) coarsest \(guide.unitLabel)"
    guard let range = GrinderGuide.method(forMethodNamed: methodName).flatMap(guide.range(for:))
    else { return "Grinder: \(name) (\(scale))" }
    return "Grinder: \(name) (\(scale); guide's starting range for this brewer: \(range))"
  }

  /// The AI's grind as a stop on the grinder's wheel ("34 on the dial" finds "34"), or the
  /// first number it gave when that is off the wheel; nil with no grinder or no number.
  static func wheelSetting(_ grind: String, grinder: String?) -> String? {
    guard let grinder, !grinder.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
    let stops = GrinderGuide.find(grinder)?.settings ?? GrinderGuide.otherSettings
    let tokens = grind.split(whereSeparator: \.isWhitespace).map {
      $0.trimmingCharacters(in: CharacterSet(charactersIn: ",;:()"))
    }
    return tokens.lazy.compactMap { GrinderGuide.setting($0, in: stops) }.first
      ?? tokens.first { $0.contains(where: \.isNumber) }
  }

  /// The tuning note with the AI's grind as its last line, replacing an earlier one. No
  /// grind leaves the note as it was.
  static func note(_ note: String?, grind: String, grinder: String?) -> String? {
    guard let grinder, !grinder.isEmpty, !grind.isEmpty else { return note }
    var lines = (note ?? "").components(separatedBy: "\n").filter { !$0.hasPrefix("Grind: ") }
    while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
    if !lines.isEmpty { lines.append("") }
    lines.append("Grind: \(grind) on \(grinder).")
    return lines.joined(separator: "\n")
  }

  /// The AI's summary followed by the pages its research cited, one per line, so the
  /// recipe says where it came from.
  static func summary(_ summary: String, sources: [WebSource]) -> String? {
    var parts = summary.isEmpty ? [] : [summary]
    if !sources.isEmpty {
      parts.append(
        (["Sources:"] + sources.prefix(5).map { "\($0.title): \($0.url.absoluteString)" })
          .joined(separator: "\n"))
    }
    return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
  }

  /// The recipe as text: brewer, grinder, numbers, the user's note and every step. No
  /// photo, no beans, no brews.
  static func payload(
    _ draft: RecipeDraft, methodName: String?, note: String, grinder: String? = nil
  ) -> AIRequestPayload {
    var lines = [
      "Recipe: \(draft.name)" + (methodName.map { " on a \($0)" } ?? ""),
      "Dose: \(grams(draft.doseG)) g, total water: \(grams(draft.waterG)) g"
        + (draft.includesIce ? ", ice: \(grams(draft.iceG ?? 0)) g" : "")
        + ", temperature: " + (draft.tempC.map { "\(Int($0.rounded())) °C" } ?? "not set")
        + ", total time: " + (draft.totalTimeS.map { "\($0) s" } ?? "not set"),
    ]
    if let line = grinderLine(grinder, methodName: methodName) { lines.append(line) }
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
      system: improveSystem, userText: lines.joined(separator: "\n"),
      schemaName: "recipe_review", schema: schema)
  }

  /// What the web search is asked: the same brewer, grinder and note Create with AI sends.
  static func researchQuestion(methodName: String, style: String, note: String, grinder: String?)
    -> String
  {
    [
      "Brewer: \(methodName) (\(style))",
      grinder.map { "Grinder: \($0)" },
      "What they want: \(note.trimmingCharacters(in: .whitespacesAndNewlines))",
    ].compactMap { $0 }.joined(separator: "\n")
  }

  /// A new recipe: only the brewer, the grinder, the note and, with a keyed provider, what
  /// its web search found. No beans, brews or photos.
  static func createPayload(
    methodName: String, style: String, note: String, grinder: String? = nil,
    research: WebResearch? = nil
  ) -> AIRequestPayload {
    let lines = [
      "Brewer: \(methodName) (\(style))",
      grinderLine(grinder, methodName: methodName),
      "What they want: \(note.trimmingCharacters(in: .whitespacesAndNewlines))",
      research.map { "What coffee sites recommend:\n\($0.notes)" },
    ].compactMap { $0 }
    return AIRequestPayload(
      system: createSystem, userText: lines.joined(separator: "\n"),
      schemaName: "recipe_create", schema: schema)
  }

  static func review(_ payload: AIRequestPayload, base: RecipeDraft, mode: Mode = .improve)
    async throws -> Review
  {
    let (answer, source) = try await DirectAI.send(payload)
    guard let review = parse(answer, base: base, source: source, mode: mode) else {
      throw AIError.invalidResponse
    }
    return review
  }

  /// Keeps an answer only when it makes a recipe the editor itself would save and its pours
  /// add up to its water. Water on a step that pours nothing is dropped, and an
  /// instruction that only repeats the step's name is cleared.
  static func parse(
    _ answer: [String: Any], base: RecipeDraft, source: String, mode: Mode = .improve
  ) -> Review? {
    guard let rawSteps = answer["steps"] as? [[String: Any]],
      (1...maxSteps).contains(rawSteps.count)
    else { return nil }
    var steps: [RecipeStepDraft] = []
    for raw in rawSteps {
      guard let kind = (raw["kind"] as? String).flatMap(StepKind.init(rawValue:)),
        let at = (raw["atS"] as? NSNumber)?.intValue, (0...86_400).contains(at)
      else { return nil }
      let water = (raw["waterG"] as? NSNumber)?.doubleValue ?? 0
      var instruction = (raw["instruction"] as? String ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if [kind.rawValue, RecipeFormat.title(kind)].contains(where: {
        $0.caseInsensitiveCompare(instruction) == .orderedSame
      }) {
        instruction = ""
      }
      steps.append(
        RecipeStepDraft(
          kind: kind, startOffsetS: at,
          targetCumulativeWaterG: pouringKinds.contains(kind) && water > 0
            ? water.rounded() : nil,
          instruction: String(instruction.prefix(300))))
    }
    steps = valvesOnly(steps)
    func number(_ key: String) -> Double { (answer[key] as? NSNumber)?.doubleValue ?? 0 }
    var draft = base
    draft.steps = RecipeEditorService.sorted(steps)
    let dose = number("doseG")
    let water = number("waterG")
    if (1...250).contains(dose) { draft.doseG = (dose * 10).rounded() / 10 }
    if (10...4_000).contains(water) { draft.waterG = water.rounded() }
    let temp = number("tempC")
    let time = (answer["totalTimeS"] as? NSNumber)?.intValue ?? 0
    if (1...100).contains(temp) { draft.tempC = temp.rounded() }
    if (10...86_400).contains(time) { draft.totalTimeS = time }
    if mode == .create {
      let name = (answer["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      if !name.isEmpty { draft.name = String(name.prefix(60)) }
    }
    guard RecipeEditorService.validate(draft) == nil, pourAddsUp(draft) else { return nil }
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
      changes: changes, draft: draft, source: source,
      grind: String(
        (answer["grind"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
          .prefix(40)))
  }

  /// Valve steps only work the valve: one whose instruction also pours or doses (the next
  /// step does that) gets a plain one, and a recipe that opens a valve it never closed
  /// starts by closing it, so the timer shows the valve as its own step.
  static func valvesOnly(_ steps: [RecipeStepDraft]) -> [RecipeStepDraft] {
    var steps = steps.map { step -> RecipeStepDraft in
      var step = step
      let lower = step.instruction.lowercased()
      let doesMore =
        lower.contains("pour")
        || lower.range(of: #"\d\s?g\b"#, options: .regularExpression) != nil
      if step.kind == .closeValve, doesMore { step.instruction = "Close the valve." }
      if step.kind == .openValve, doesMore { step.instruction = "Open the valve to drain." }
      return step
    }
    let sorted = RecipeEditorService.sorted(steps)
    if sorted.contains(where: { $0.kind == .openValve }),
      let first = sorted.first, first.kind != .closeValve, first.kind != .openValve
    {
      steps.insert(
        RecipeStepDraft(kind: .closeValve, startOffsetS: 0, instruction: "Close the valve."),
        at: 0)
    }
    return steps
  }

  /// The last pour reaches the recipe's water (within 2%), so no water is left unpoured.
  /// Recipes over ice, and ones with no pour targets at all, are left to the editor's checks.
  static func pourAddsUp(_ draft: RecipeDraft) -> Bool {
    guard !draft.includesIce,
      let last = draft.steps.compactMap(\.targetCumulativeWaterG).max()
    else { return true }
    return abs(last - draft.waterG) <= max(2, draft.waterG * 0.02)
  }

  private static func grams(_ value: Double) -> String {
    value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
  }
}
