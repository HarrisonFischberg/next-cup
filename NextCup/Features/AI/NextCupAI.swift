import Foundation
import NextCupKit
import SwiftData

/// "Ask AI for Next Cup" on a past brew: the AI reads the brew and how it tasted and rewrites
/// it as an improved recipe, saved as the user's own "Next Cup" on the Brew tab. There is one
/// rolling Next Cup per method; renaming it keeps it, and the next ask makes a new one.
@MainActor
enum NextCupAI {
  nonisolated static let recipeName = "Next Cup"
  /// With the name, marks a recipe this feature owns, so a recipe the user happened to name
  /// "Next Cup" is never replaced.
  nonisolated static let credit = "AI, from your brew"

  struct Outcome: Equatable {
    var recipeID: UUID
    var summary: String
    var changes: [RecipeReviewAI.Change]
    var source: String
    /// The earlier Next Cup this one replaced, so it can be put back.
    var replaced: RecipeDraft?
  }

  private static let system =
    """
    You are an expert specialty coffee barista dialing in a home brewer's next cup from the \
    cup they just made. Decide what to change from its rating, taste and their notes: sour or \
    thin usually means extract more (finer, hotter or longer), bitter or harsh means extract \
    less (coarser, cooler or shorter), weak means less water for the coffee. A cup rated \
    highly needs only small changes. Change as little as fixes the problem, in small real \
    steps, and allow for the bean's roast. Start from the grind they used. Keep the brewer, \
    and keep the dose and total water unless the ratio is the problem. Keep their steps unless \
    the technique is the problem; when none are listed, write sound ones for the brewer. A \
    dose or water of 0 was not recorded. When notes from coffee sites are given, use them \
    only where they fit this cup. changes lists each change, as what (a few words with the \
    old and new value, for example "Grind 18 to 16") and why (one sentence). Keep the \
    recipe's name.
    """ + "\n" + RecipeReviewAI.format

  /// The brew as a recipe to improve: its own recipe's steps with the numbers it was
  /// actually brewed at.
  static func base(for brew: Brew, store: Store) -> RecipeDraft {
    var draft =
      brew.recipe.map { RecipeEditorService(store: store).draft(from: $0, asCopy: true) }
      ?? RecipeDraft()
    draft.name = brew.recipe?.name ?? "Logged brew"
    draft.methodID = brew.method?.id ?? draft.methodID
    draft.doseG = brew.doseG ?? draft.doseG
    draft.waterG = brew.waterG ?? draft.waterG
    draft.tempC = brew.tempC ?? draft.tempC
    draft.totalTimeS = brew.totalTimeS ?? draft.totalTimeS
    draft.grindSetting = brew.grindSetting ?? draft.grindSetting
    draft.grinderName = brew.grinder?.name ?? draft.grinderName
    return draft
  }

  /// The brew, its beans and how it tasted, then the recipe the way Improve with AI sends it.
  /// No photo and no other brews.
  static func payload(for brew: Brew, base: RecipeDraft) -> AIRequestPayload {
    var lines = (brew.beans ?? []).map(beanLine)
    if let grind = brew.grindSetting, !grind.isEmpty { lines.append("Grind used: \(grind)") }
    let rating = brew.ratingTenths.flatMap { $0 > 0 ? Rating.text($0) : nil }
    lines.append("Rating: " + (rating.map { "\($0) out of 10" } ?? "not rated"))
    lines.append(
      "Taste: "
        + (brew.verdicts.isEmpty
          ? "not noted" : brew.verdicts.map(\.rawValue).joined(separator: ", ")))
    let notes = brew.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    if !notes.isEmpty { lines.append("Their notes on this cup: \(notes)") }
    let recipe = RecipeReviewAI.payload(
      base, methodName: brew.method?.name, note: "", grinder: base.grinderName)
    lines.append(recipe.userText)
    return AIRequestPayload(
      system: system, userText: lines.joined(separator: "\n"), schemaName: "next_cup",
      schema: RecipeReviewAI.schema)
  }

  private static func beanLine(_ part: BrewBean) -> String {
    let bean = part.bean
    var line = "Bean: \(bean?.name ?? part.beanNameSnapshot)"
    if let roaster = bean?.roaster?.name { line += " from \(roaster)" }
    if let roast = bean?.roastLevel { line += ", \(roast.rawValue) roast" }
    if let origin = bean?.originCountry { line += ", \(origin)" }
    if let process = bean?.process { line += ", \(process) process" }
    if let flavors = bean?.bagFlavorNotes, !flavors.isEmpty {
      line += ", bag says \(flavors.joined(separator: ", "))"
    }
    return line
  }

  /// What the web search is asked: the brewer, grinder, roast and taste. Never the bean's
  /// name or the user's notes.
  static func researchQuestion(for brew: Brew, grinder: String?) -> String? {
    guard let method = brew.method else { return nil }
    let roast = (brew.beans ?? []).compactMap { $0.bean?.roastLevel?.rawValue }.first
    var want = "A better next cup" + (roast.map { " of a \($0) roast" } ?? "")
    if !brew.verdicts.isEmpty {
      want += " than one that tasted " + brew.verdicts.map(\.rawValue).joined(separator: " and ")
    }
    return RecipeReviewAI.researchQuestion(
      methodName: method.name, style: RecipeFormat.title(method.style), note: want,
      grinder: grinder)
  }

  /// The answer as the recipe to save: named Next Cup, with the AI's changes in its note and
  /// the grind carried in (the AI's when it gave one, else the brew's).
  static func finished(_ review: RecipeReviewAI.Review, brew: Brew, sources: [WebSource] = [])
    -> RecipeDraft
  {
    var draft = review.draft
    let grinder = draft.grinderName
    draft.sourceID = nil
    draft.name = recipeName
    draft.credit = credit
    draft.creditURL = nil
    var parts = [origin(of: brew)]
    if !review.changes.isEmpty {
      parts.append(
        (["AI changes:"]
          + review.changes.map { "• \($0.what)" + ($0.why.isEmpty ? "" : ": \($0.why)") })
          .joined(separator: "\n"))
    }
    if let summary = RecipeReviewAI.summary(review.summary, sources: sources) {
      parts.append(summary)
    }
    draft.tuningNote = RecipeReviewAI.note(
      parts.joined(separator: "\n\n"), grind: review.grind, grinder: grinder)
    draft.grindSetting =
      RecipeReviewAI.wheelSetting(review.grind, grinder: grinder) ?? draft.grindSetting
    return draft
  }

  /// "From your Geometry brew on Oct 27, rated 7.9."
  private static func origin(of brew: Brew) -> String {
    var line = "From your " + (brew.beanNames.first.map { "\($0) " } ?? "") + "brew on "
    line += brew.date.formatted(.dateTime.month(.abbreviated).day())
    if let tenths = brew.ratingTenths, tenths > 0 { line += ", rated \(Rating.text(tenths))" }
    return line + "."
  }

  /// Saves `draft` over this method's Next Cup, or as a new recipe when it has none.
  static func save(_ draft: RecipeDraft, store: Store) -> Result<
    (recipe: Recipe, replaced: RecipeDraft?), RecipeEditorError
  > {
    let service = RecipeEditorService(store: store)
    let recipes = (try? store.context.fetch(FetchDescriptor<Recipe>())) ?? []
    let existing = recipes.first { $0.isNextCup && $0.method?.id == draft.methodID }
    var draft = draft
    draft.sourceID = existing?.id
    let replaced = existing.map { service.draft(from: $0, asCopy: false) }
    return service.save(draft).map { ($0, replaced) }
  }

  /// Asks the AI about `brew` and saves the answer. Nothing is stored unless the answer makes
  /// a recipe the editor itself would save. A failed web search never blocks the recipe.
  static func ask(
    about brew: Brew, store: Store,
    research: (String) async throws -> WebResearch? = {
      try await DirectAI.research($0, system: RecipeReviewAI.researchSystem)
    },
    send: (AIRequestPayload) async throws -> (answer: [String: Any], source: String) = {
      try await DirectAI.send($0)
    }
  ) async throws -> Outcome {
    let start = base(for: brew, store: store)
    let found = await searchResult(for: brew, grinder: start.grinderName, research: research)
    try Task.checkCancellation()
    let (answer, source) = try await send(payload(for: brew, base: start))
    try Task.checkCancellation()
    guard let review = RecipeReviewAI.parse(answer, base: start, source: source) else {
      throw AIError.invalidResponse
    }
    switch save(finished(review, brew: brew, sources: found?.sources ?? []), store: store) {
    case .success(let saved):
      return Outcome(
        recipeID: saved.recipe.id, summary: review.summary, changes: review.changes,
        source: source, replaced: saved.replaced)
    case .failure(let failure):
      throw failure
    }
  }

  private static func searchResult(
    for brew: Brew, grinder: String?, research: (String) async throws -> WebResearch?
  ) async -> WebResearch? {
    guard let question = researchQuestion(for: brew, grinder: grinder) else { return nil }
    return try? await research(question)
  }

  #if DEBUG
    /// UI tests and screenshots: the live AI cannot run in the simulator, so `-fakeNextCupAI`
    /// answers with this through the same parsing and saving.
    static let fakesAnswer = ProcessInfo.processInfo.arguments.contains("-fakeNextCupAI")
    static func fakeAnswer(for base: RecipeDraft) -> [String: Any] {
      [
        "summary": "A finer grind and hotter water pull more sweetness from this coffee.",
        "changes": [
          ["what": "Grind 18 to 16", "why": "A finer grind extracts more and fixes the sourness."],
          ["what": "Temperature 93 to 95 °C", "why": "Hotter water helps a light roast."],
        ],
        "name": "", "doseG": base.doseG, "waterG": base.waterG, "tempC": 95,
        "totalTimeS": 210, "grind": "16",
        "steps": [
          [
            "kind": "bloom", "atS": 0, "waterG": (base.doseG * 3).rounded(),
            "instruction": "Pour three times the coffee's weight and let it bloom.",
          ],
          [
            "kind": "pour", "atS": 45, "waterG": base.waterG,
            "instruction": "Pour the rest in a slow spiral.",
          ],
          ["kind": "drawdown", "atS": 120, "waterG": 0, "instruction": "Let it drain fully."],
        ],
      ]
    }
  #endif
}

extension Recipe {
  /// The rolling recipe `NextCupAI` writes. Renamed or duplicated, it is the user's own.
  var isNextCup: Bool {
    builtInKey == nil && name == NextCupAI.recipeName && credit == NextCupAI.credit
  }
}
