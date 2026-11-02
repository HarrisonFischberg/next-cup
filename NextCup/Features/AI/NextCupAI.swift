import Foundation
import NextCupKit
import SwiftData

/// "Ask AI for Next Cup" on a past brew: the AI reads the brew, how it tasted and the user's
/// similar past brews, gives an overview and rewrites the brew as an improved recipe, which the
/// user can save as their own "Next Cup" on the Brew tab. There is one rolling Next Cup per method;
/// renaming it keeps it, and the next ask makes a new one.
@MainActor
enum NextCupAI {
  nonisolated static let recipeName = "Next Cup"
  /// With the name, marks a recipe this feature owns, so a recipe the user happened to name
  /// "Next Cup" is never replaced.
  nonisolated static let credit = "AI, from your brew"

  struct Outcome: Equatable {
    /// The recipe to save. Nothing is stored until the user saves it.
    var draft: RecipeDraft
    var summary: String
    var changes: [RecipeReviewAI.Change]
    var source: String
    /// Saving this overwrites an earlier Next Cup for the method.
    var replacesEarlier: Bool
    /// How many of the user's other brews the AI read.
    var similarCount = 0
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
    recipe's name. Read their other similar brews as the trend: which settings got the best \
    ratings and tastes, what changed between cups and what that did. Keep what worked, do not \
    repeat what failed, and allow for differences in bean.
    """ + "\n" + RecipeReviewAI.format + "\n"
      + """
      For this answer, summary is not one or two sentences: it is a full overview of 3 to 6 \
      plain sentences covering what this cup says, what their similar brews show, and the plan \
      for the next cup.
      """

  /// How much history fits: Apple's on-device model has a small context.
  nonisolated static let cloudHistory = (brews: 8, noteCharacters: 240)
  nonisolated static let onDeviceHistory = (brews: 4, noteCharacters: 120)

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

  /// The user's other brews with this brew's method, any date: those sharing a bean first,
  /// then those with a similar dose and water, then the rest, newest first within each.
  static func similarBrews(to brew: Brew, in brews: [Brew], limit: Int) -> [Brew] {
    guard let method = brew.method?.id else { return [] }
    let beans = Set((brew.beans ?? []).map(beanKey))
    func tier(_ other: Brew) -> Int {
      if !beans.isDisjoint(with: (other.beans ?? []).map(beanKey)) { return 0 }
      return isNear(other.doseG, brew.doseG) && isNear(other.waterG, brew.waterG) ? 1 : 2
    }
    let others = brews.filter { $0.id != brew.id && $0.method?.id == method }
    let ranked: [(tier: Int, brew: Brew)] = others.map { (tier($0), $0) }
    let sorted = ranked.sorted { (first, second) -> Bool in
      first.tier == second.tier ? first.brew.date > second.brew.date : first.tier < second.tier
    }
    return sorted.prefix(limit).map { $0.brew }
  }

  /// The pool for the automatic Next Cup: brews already rated or tasted, with the same method
  /// (checked by `similarBrews`) and a dose and water within 20% of this brew's.
  static func sameCategory(as brew: Brew, in brews: [Brew]) -> [Brew] {
    brews.filter {
      $0.isReviewed && isNear($0.doseG, brew.doseG) && isNear($0.waterG, brew.waterG)
    }
  }

  /// A bean deleted since the brew is known only by the name the brew kept.
  private static func beanKey(_ part: BrewBean) -> String {
    part.bean?.id.uuidString ?? part.beanNameSnapshot
  }

  /// Within 20% of `value`. A missing or 0 amount was not recorded, so it matches.
  private static func isNear(_ other: Double?, _ value: Double?) -> Bool {
    guard let other, let value, other > 0, value > 0 else { return true }
    return abs(other - value) <= value * 0.2
  }

  /// One past brew on one line. No photo.
  private static func historyLine(_ brew: Brew, noteCharacters: Int) -> String {
    var parts = [brew.date.formatted(date: .abbreviated, time: .omitted)]
    if let recipe = brew.recipe?.name { parts.append(recipe) }
    for part in brew.beans ?? [] {
      var bean = "bean \(part.bean?.name ?? part.beanNameSnapshot)"
      if let roaster = part.bean?.roaster?.name { bean += " from \(roaster)" }
      if let roast = part.bean?.roastLevel { bean += ", \(roast.rawValue) roast" }
      parts.append(bean)
    }
    if let dose = brew.doseG, dose > 0 {
      parts.append("dose \(SuggestionApplication.number(dose)) g")
    }
    if let water = brew.waterG, water > 0 {
      parts.append("water \(SuggestionApplication.number(water)) g")
    }
    if let ratio = BrewMath.ratioLabel(BrewMath.ratio(doseG: brew.doseG, waterG: brew.waterG)) {
      parts.append("ratio \(ratio)")
    }
    let grind = brew.grindSetting.flatMap { $0.isEmpty ? nil : $0 }
    if let grinder = brew.grinder?.name {
      parts.append("grinder \(grinder)" + (grind.map { " at \($0)" } ?? ""))
    } else if let grind {
      parts.append("grind \(grind)")
    }
    if let temp = brew.tempC { parts.append("\(SuggestionApplication.number(temp)) °C") }
    if let time = brew.totalTimeS { parts.append("\(time) s") }
    parts.append(
      "taste "
        + (brew.verdicts.isEmpty
          ? "not noted" : brew.verdicts.map(\.rawValue).joined(separator: ", ")))
    parts.append(ratingText(brew))
    let notes = brew.notes.components(separatedBy: .newlines).joined(separator: " ")
      .trimmingCharacters(in: .whitespaces)
    if !notes.isEmpty {
      parts.append(
        "notes: \(notes.prefix(noteCharacters))" + (notes.count > noteCharacters ? "…" : ""))
    }
    return "- " + parts.joined(separator: "; ")
  }

  private static func ratingText(_ brew: Brew) -> String {
    brew.ratingTenths.flatMap { $0 > 0 ? "rated \(Rating.text($0)) out of 10" : nil } ?? "not rated"
  }

  /// The brew, its beans and how it tasted, the recipe the way Improve with AI sends it, then
  /// the user's similar past brews. No photos.
  static func payload(
    for brew: Brew, base: RecipeDraft, similar: [Brew] = [],
    noteCharacters: Int = cloudHistory.noteCharacters
  ) -> AIRequestPayload {
    var lines = ["Brewed: \(brew.date.formatted(date: .abbreviated, time: .omitted))"]
    lines += (brew.beans ?? []).map(beanLine)
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
    lines.append("Their other similar brews, newest first:" + (similar.isEmpty ? " none yet" : ""))
    lines += similar.map { historyLine($0, noteCharacters: noteCharacters) }
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
  static func save(_ draft: RecipeDraft, store: Store) -> Result<Recipe, RecipeEditorError> {
    var draft = draft
    draft.sourceID = existing(for: draft, store: store)?.id
    return RecipeEditorService(store: store).save(draft)
  }

  private static func existing(for draft: RecipeDraft, store: Store) -> Recipe? {
    let recipes = (try? store.context.fetch(FetchDescriptor<Recipe>())) ?? []
    return recipes.first { $0.isNextCup && $0.method?.id == draft.methodID }
  }

  /// Asks the AI about `brew` and returns the recipe to save. An answer that does not make a
  /// recipe the editor itself would save throws. A failed web search never blocks the recipe.
  static func ask(
    about brew: Brew, store: Store, sameCategoryOnly: Bool = false,
    onDevice: Bool = DirectAI.cloudProviderTitle == nil,
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
    try checkStillThere(brew)
    let history = onDevice ? onDeviceHistory : cloudHistory
    let all = (try? store.context.fetch(FetchDescriptor<Brew>())) ?? []
    let similar = similarBrews(
      to: brew, in: sameCategoryOnly ? sameCategory(as: brew, in: all) : all,
      limit: history.brews)
    let (answer, source) = try await send(
      payload(for: brew, base: start, similar: similar, noteCharacters: history.noteCharacters))
    try Task.checkCancellation()
    try checkStillThere(brew)
    guard let review = RecipeReviewAI.parse(answer, base: start, source: source) else {
      throw AIError.invalidResponse
    }
    let draft = finished(review, brew: brew, sources: found?.sources ?? [])
    if let problem = RecipeEditorService.validate(draft) { throw problem }
    return Outcome(
      draft: draft, summary: review.summary, changes: review.changes, source: source,
      replacesEarlier: existing(for: draft, store: store) != nil, similarCount: similar.count)
  }

  /// The automatic run has no sheet in front of the Journal, so the brew can be deleted while
  /// the AI works, and reading a deleted brew can crash.
  private static func checkStillThere(_ brew: Brew) throws {
    if brew.isDeleted || brew.modelContext == nil { throw CancellationError() }
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
        "summary":
          "This cup tasted sour, so it needs more extraction. Your similar brews rated higher "
          + "when they were ground finer. Next time, go finer and hotter to pull more sweetness.",
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

extension Brew {
  /// Rated or tasted. Notes alone say too little to change a recipe.
  var isReviewed: Bool { !verdicts.isEmpty || (ratingTenths ?? 0) > 0 }
  /// What the AI reads as the review, to tell whether an edit changed it.
  var reviewKey: String { "\(verdicts)|\(ratingTenths ?? 0)|\(notes)" }
}

extension Recipe {
  /// The rolling recipe `NextCupAI` writes. Renamed or duplicated, it is the user's own.
  var isNextCup: Bool {
    builtInKey == nil && name == NextCupAI.recipeName && credit == NextCupAI.credit
  }
}
