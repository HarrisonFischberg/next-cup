import Foundation
import NextCupKit
import SwiftData

/// "Ways to brew [bean]" after a bag is scanned: the AI reads the bean and up to three tastes
/// the user picked (one recipe for each), or none for its own three best, each on a different
/// brewer of the user's with a grind. Nothing is stored until the user taps Save on one, which
/// keeps it under "Recipe to try for your Next Cup" on the Brew tab until it is brewed.
@MainActor
enum BeanBrewAI {
  /// With a pick's name, marks a recipe this feature saved, so starting the same pick again
  /// replaces it instead of piling up copies.
  nonisolated static let credit = "AI, for your taste"
  nonisolated static let pickCount = 3

  /// Quick picks under the text field; any free text works too.
  nonisolated static let goals = [
    "Chocolatey and full-bodied", "Bright and fruity", "Sweet and balanced",
    "Clean and tea-like", "Strong and bold", "Floral and delicate",
  ]

  struct Pick: Equatable, Identifiable {
    var id = UUID()
    var methodName: String
    /// One or two sentences on why this brewer and recipe fit the bean and the goal.
    var why: String
    /// The recipe to save: method, numbers, steps and grind.
    var draft: RecipeDraft
    var grind: String
    /// The taste this recipe was made for; empty for the AI's own picks.
    var goal = ""
  }

  struct Outcome: Equatable {
    var summary: String
    /// Best first.
    var picks: [Pick]
    var source: String
  }

  private static let system =
    """
    You are an expert specialty coffee barista helping a home brewer brew a coffee they \
    just bought. From the bean's roaster, origin, process, roast and bag flavors, and what \
    they want the cup to taste like, pick the 3 best ways to brew it, as first, second and third, \
    each on a different brewer from their list. Choose brewers that suit the goal: a full-bodied, \
    chocolatey cup favors immersion, metal filters or a finer grind and slightly longer \
    contact; a bright, clean cup favors paper-filtered pour over and hotter water for light \
    roasts. When several tastes are listed, the first recipe reaches the first taste, the \
    second the second, and so on. When no goal is given, pick what brings out the best in \
    this bean. method is \
    the brewer's name exactly as listed. why is one or two sentences on how this recipe \
    reaches their goal with this bean. Keep each recipe simple, at most 8 steps, with a \
    sound ratio and temperature for the brewer and roast. name is a short title of two to \
    four words. summary is one or two plain sentences on what this bean is like and the \
    plan.
    """ + "\n" + RecipeReviewAI.format

  /// method is limited to the user's brewer names, so no model can name one they lack.
  /// Three fixed slots, not a list: Apple's small model often lists only two. method is
  /// limited to the user's brewer names, so no model can name one they lack.
  static func schema(methodNames: [String]) -> JSONSchema {
    let pick = JSONSchema.object([
      "method": .string(allowed: methodNames),
      "why": .string(),
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
    return .object(["summary": .string(), "first": pick, "second": pick, "third": pick])
  }

  private static let slots = ["first", "second", "third"]

  /// The brewers the AI may choose from: the user's methods that are not hidden.
  static func methods(store: Store) -> [BrewMethod] {
    let all = (try? store.context.fetch(FetchDescriptor<BrewMethod>())) ?? []
    return all.filter { !$0.isHidden }.sorted { $0.sortOrder < $1.sortOrder }
  }

  /// The bean, the goal, the brewers and the grinder. No photo, no brews, no notes.
  static func payload(bean: Bean, goal: String, methods: [BrewMethod], grinder: String?)
    -> AIRequestPayload
  {
    payload(bean: bean, goals: [goal], methods: methods, grinder: grinder)
  }

  static func payload(bean: Bean, goals: [String], methods: [BrewMethod], grinder: String?)
    -> AIRequestPayload
  {
    var lines = [beanLine(bean)]
    let goals = clean(goals)
    switch goals.count {
    case 0: lines.append("What they want: no preference, recommend the best for this bean")
    case 1: lines.append("What they want it to taste like: \(goals[0])")
    default:
      lines.append(
        "One recipe for each taste, in this order: "
          + goals.enumerated().map { "\(slots[$0.offset]): \($0.element)" }
          .joined(separator: "; "))
    }
    lines.append(
      "Their brewers: "
        + methods.map { "\($0.name) (\(RecipeFormat.title($0.style)))" }.joined(separator: "; "))
    if let line = RecipeReviewAI.grinderLine(grinder, methodName: nil) { lines.append(line) }
    return AIRequestPayload(
      system: system, userText: lines.joined(separator: "\n"), schemaName: "bean_brew",
      schema: schema(methodNames: methods.map(\.name)))
  }

  /// Trimmed, non-empty, at most three, each at most 300 characters.
  static func clean(_ goals: [String]) -> [String] {
    goals.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)) }
      .filter { !$0.isEmpty }.prefix(pickCount).map { $0 }
  }

  private static func beanLine(_ bean: Bean) -> String {
    var line = "Bean: \(bean.name)"
    if let roaster = bean.roaster?.name { line += " from \(roaster)" }
    if let roast = bean.roastLevel { line += ", \(roast.rawValue) roast" }
    if let origin = bean.originCountry { line += ", \(origin)" }
    if let process = bean.process { line += ", \(process) process" }
    if !bean.bagFlavorNotes.isEmpty {
      line += ", bag says \(bean.bagFlavorNotes.joined(separator: ", "))"
    }
    return line
  }

  /// Keeps each pick that names one of the user's brewers (once), best first, at most three.
  /// The AI's own recipe is used when the editor would save it and its ratio is sound for the
  /// brewer; otherwise (Apple's small model often gets the numbers wrong) the brewer's built-in
  /// recipe from `fallback` is used with the AI's name, temperature and grind. Nil when none
  /// survive.
  static func parse(
    _ answer: [String: Any], methods: [BrewMethod], grinder: String?, bean: Bean, source: String,
    fallback: (BrewMethod) -> RecipeDraft? = { _ in nil }
  ) -> Outcome? {
    var picks: [Pick] = []
    var used = Set<UUID>()
    let raws =
      answer["picks"] as? [[String: Any]] ?? slots.compactMap { answer[$0] as? [String: Any] }
    for raw in raws {
      guard picks.count < pickCount,
        let name = (raw["method"] as? String)?.trimmingCharacters(in: .whitespaces),
        let method = methods.first(where: {
          $0.name.caseInsensitiveCompare(name) == .orderedSame
        }),
        !used.contains(method.id)
      else { continue }
      var base = RecipeDraft()
      base.methodID = method.id
      base.name = "\(bean.name) on \(method.name)"
      base.grinderName = grinder
      let grind = String(
        (raw["grind"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
      var draft: RecipeDraft
      if let review = RecipeReviewAI.parse(raw, base: base, source: source, mode: .create),
        isSound(review.draft, style: method.style)
      {
        draft = review.draft
      } else if var builtIn = fallback(method) {
        builtIn.name = aiName(raw) ?? base.name
        builtIn.methodID = method.id
        builtIn.grinderName = grinder
        if method.style != .cold, let temp = (raw["tempC"] as? NSNumber)?.doubleValue,
          (85...96).contains(temp)
        {
          builtIn.tempC = temp.rounded()
        }
        draft = builtIn
      } else {
        continue
      }
      used.insert(method.id)
      draft.sourceID = nil
      draft.credit = credit
      draft.creditURL = nil
      let why = (raw["why"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      draft.tuningNote = RecipeReviewAI.note(
        ["For \(bean.name).", why].filter { !$0.isEmpty }.joined(separator: " "),
        grind: grind, grinder: grinder)
      draft.grindSetting = RecipeReviewAI.wheelSetting(grind, grinder: grinder)
      picks.append(Pick(methodName: method.name, why: why, draft: draft, grind: grind))
    }
    guard !picks.isEmpty else { return nil }
    // A repeated or unusable slot is filled with another brewer's built-in recipe, a brewer of
    // the same style as the picks first, so there are always three to choose from.
    let styles = Set(
      picks.compactMap { pick in methods.first { $0.name == pick.methodName }?.style })
    let spares = methods.filter { !used.contains($0.id) }
      .sorted { styles.contains($0.style) && !styles.contains($1.style) }
    for method in spares where picks.count < pickCount {
      guard var draft = fallback(method) else { continue }
      draft.methodID = method.id
      draft.grinderName = grinder
      draft.sourceID = nil
      draft.credit = credit
      draft.creditURL = nil
      draft.tuningNote = "For \(bean.name)."
      picks.append(Pick(methodName: method.name, why: "", draft: draft, grind: ""))
    }
    let summary = (answer["summary"] as? String ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return Outcome(summary: summary, picks: picks, source: source)
  }

  private static func aiName(_ raw: [String: Any]) -> String? {
    let name = (raw["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? nil : String(name.prefix(60))
  }

  /// Water for the coffee in a range real recipes use for the brewer (espresso and moka
  /// about 1:1.5 to 1:10, cold brew, often a concentrate, 1:4 to 1:20, the rest 1:12 to 1:20),
  /// and for pour over and immersion at least two steps and 1.5 to 10 minutes.
  static func isSound(_ draft: RecipeDraft, style: BrewStyle) -> Bool {
    guard draft.doseG > 0 else { return false }
    let ratio = draft.waterG / draft.doseG
    switch style {
    case .espresso: return (1.5...10).contains(ratio)
    case .cold: return (4...20).contains(ratio)
    default:
      return (12...20).contains(ratio) && draft.steps.count >= 2
        && (90...600).contains(draft.totalTimeS ?? 0)
    }
  }

  /// The brewer's first built-in recipe, as a copy to fall back on.
  static func builtInDraft(for method: BrewMethod, store: Store) -> RecipeDraft? {
    let recipes = (method.recipes ?? []).filter { $0.builtInKey != nil }
    guard let recipe = recipes.min(by: { $0.name < $1.name }) else { return nil }
    var draft = RecipeEditorService(store: store).draft(from: recipe, asCopy: true)
    draft.name = recipe.name
    return draft
  }

  /// Saves the pick as a recipe to try, over the one this feature saved before with the same
  /// name and brewer. It shows under "Recipes for [bean]" on the Brew tab until it is brewed
  /// and rated. Its credit links to the bean (`nextcup://bean/<id>`), which groups it there.
  static func save(_ draft: RecipeDraft, bean: Bean?, store: Store) -> Result<
    Recipe, RecipeEditorError
  > {
    var draft = draft
    draft.creditURL = bean.flatMap { URL(string: "\(DeepLink.scheme)://bean/\($0.id)") }
    let recipes = (try? store.context.fetch(FetchDescriptor<Recipe>())) ?? []
    draft.sourceID =
      recipes.first {
        $0.credit == credit && $0.name == draft.name && $0.method?.id == draft.methodID
      }?.id
    return RecipeEditorService(store: store).save(draft)
  }

  /// Three picks for one goal (or none).
  static func ask(
    bean: Bean, goal: String, store: Store, grinder: String?,
    send: (AIRequestPayload) async throws -> (answer: [String: Any], source: String) = {
      try await DirectAI.send($0)
    }
  ) async throws -> Outcome {
    try await ask(
      bean: bean, goals: [goal], onePerGoal: false, store: store, grinder: grinder, send: send)
  }

  /// One pick per taste in `goals` (up to three), or three when there are none.
  static func ask(
    bean: Bean, goals: [String], onePerGoal: Bool = true, store: Store, grinder: String?,
    send: (AIRequestPayload) async throws -> (answer: [String: Any], source: String) = {
      try await DirectAI.send($0)
    }
  ) async throws -> Outcome {
    let goals = clean(goals)
    let methods = methods(store: store)
    guard !methods.isEmpty else { throw AIError.invalidResponse }
    let request = payload(bean: bean, goals: goals, methods: methods, grinder: grinder)
    // Apple's small model sometimes fails outright; one more try usually answers.
    var lastError: Error = AIError.invalidResponse
    for _ in 0..<2 {
      do {
        let (answer, source) = try await send(request)
        try Task.checkCancellation()
        if let outcome = parse(
          answer, methods: methods, grinder: grinder, bean: bean, source: source,
          fallback: { builtInDraft(for: $0, store: store) })
        {
          guard onePerGoal, !goals.isEmpty else { return outcome }
          var trimmed = outcome
          trimmed.picks = Array(outcome.picks.prefix(goals.count))
          for index in trimmed.picks.indices { trimmed.picks[index].goal = goals[index] }
          return trimmed
        }
      } catch let error where !(error is CancellationError) && !Task.isCancelled {
        if case AIError.cancelled = error { throw error }
        lastError = error
      }
    }
    throw lastError
  }

  #if DEBUG
    /// UI tests: `-fakeBeanBrewAI` answers with this through the same parsing.
    static let fakesAnswer = ProcessInfo.processInfo.arguments.contains("-fakeBeanBrewAI")
    static func fakeAnswer(methods: [BrewMethod]) -> [String: Any] {
      func pick(_ method: BrewMethod, name: String, dose: Double, water: Double, grind: String)
        -> [String: Any]
      {
        [
          "method": method.name, "name": name,
          "why": "A longer, fuller extraction brings out the cocoa in this bean.",
          "doseG": dose, "waterG": water, "tempC": 94, "totalTimeS": 240, "grind": grind,
          "steps": [
            [
              "kind": "pour", "atS": 0, "waterG": water,
              "instruction": "Pour all the water evenly over the grounds.",
            ],
            ["kind": "wait", "atS": 30, "waterG": 0, "instruction": "Let it steep."],
          ],
        ]
      }
      let picks = zip(methods.prefix(3), ["Rich and round", "Full body", "Sweet cocoa"])
        .enumerated().map { index, item in
          pick(item.0, name: item.1, dose: 18 + Double(index), water: 280, grind: "\(20 + index)")
        }
      return [
        "summary": "A medium roast with cocoa and caramel notes, so aim for body and sweetness.",
        "picks": picks,
      ]
    }
  #endif
}

extension Recipe {
  /// A brew-advice pick: it waits on the Brew tab under "Recipes for [bean]" until a brew of it
  /// is rated or tasted, then shows under "Recipes for your Next Cup" and in the user's recipes.
  var isBrewAdvice: Bool { builtInKey == nil && credit == BeanBrewAI.credit }
  var isToTry: Bool { isBrewAdvice && !(brews ?? []).contains(where: \.isReviewed) }

  /// The bean a brew-advice pick was made for.
  var adviceBeanID: UUID? {
    guard isBrewAdvice, let url = creditURL, case .bean(let id)? = DeepLink(url: url) else {
      return nil
    }
    return id
  }
}
