import Foundation
import NextCupKit
import SwiftData

/// "How do you want it to taste?" after a bag is scanned: the AI reads the bean and the
/// user's taste goal (or none, for its own best picks) and ranks three ways to brew it on the
/// user's brewers, each a whole recipe with a grind. Nothing is stored until the user taps
/// Start brew on one, which saves it as a recipe and opens it on the Brew tab.
@MainActor
enum BeanBrewAI {
  /// With a pick's name, marks a recipe this feature saved, so starting the same pick again
  /// replaces it instead of piling up copies.
  nonisolated static let credit = "AI, for your taste"
  nonisolated static let pickCount = 3

  /// Quick picks under the text field; any free text works too.
  nonisolated static let goals = [
    "Chocolatey and full-bodied", "Bright and fruity", "Sweet and balanced",
    "Clean and tea-like", "Strong and bold",
  ]

  struct Pick: Equatable, Identifiable {
    var id = UUID()
    var methodName: String
    /// One or two sentences on why this brewer and recipe fit the bean and the goal.
    var why: String
    /// The recipe to save: method, numbers, steps and grind.
    var draft: RecipeDraft
    var grind: String
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
    they want the cup to taste like, pick the 3 best ways to brew it, best first, each on a \
    different brewer from their list. Choose brewers that suit the goal: a full-bodied, \
    chocolatey cup favors immersion, metal filters or a finer grind and slightly longer \
    contact; a bright, clean cup favors paper-filtered pour over and hotter water for light \
    roasts. When no goal is given, pick what brings out the best in this bean. method is \
    the brewer's name exactly as listed. why is one or two sentences on how this recipe \
    reaches their goal with this bean. Keep each recipe simple, at most 8 steps, with a \
    sound ratio and temperature for the brewer and roast. name is a short title of two to \
    four words. summary is one or two plain sentences on what this bean is like and the \
    plan.
    """ + "\n" + RecipeReviewAI.format

  static let schema = JSONSchema.object([
    "summary": .string(),
    "picks": .array(
      .object([
        "method": .string(),
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
      ])),
  ])

  /// The brewers the AI may choose from: the user's methods that are not hidden.
  static func methods(store: Store) -> [BrewMethod] {
    let all = (try? store.context.fetch(FetchDescriptor<BrewMethod>())) ?? []
    return all.filter { !$0.isHidden }.sorted { $0.sortOrder < $1.sortOrder }
  }

  /// The bean, the goal, the brewers and the grinder. No photo, no brews, no notes.
  static func payload(bean: Bean, goal: String, methods: [BrewMethod], grinder: String?)
    -> AIRequestPayload
  {
    var lines = [beanLine(bean)]
    let goal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
    lines.append(
      goal.isEmpty
        ? "What they want: no preference, recommend the best for this bean"
        : "What they want it to taste like: \(String(goal.prefix(300)))")
    lines.append(
      "Their brewers: "
        + methods.map { "\($0.name) (\(RecipeFormat.title($0.style)))" }.joined(separator: "; "))
    if let line = RecipeReviewAI.grinderLine(grinder, methodName: nil) { lines.append(line) }
    return AIRequestPayload(
      system: system, userText: lines.joined(separator: "\n"), schemaName: "bean_brew",
      schema: schema)
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

  /// Keeps each pick that names one of the user's brewers (once) and makes a recipe the
  /// editor would save, best first, at most three. Nil when none survive.
  static func parse(
    _ answer: [String: Any], methods: [BrewMethod], grinder: String?, bean: Bean, source: String
  ) -> Outcome? {
    var picks: [Pick] = []
    var used = Set<UUID>()
    for raw in answer["picks"] as? [[String: Any]] ?? [] {
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
      guard let review = RecipeReviewAI.parse(raw, base: base, source: source, mode: .create)
      else { continue }
      used.insert(method.id)
      var draft = review.draft
      draft.credit = credit
      let why = (raw["why"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      draft.tuningNote = RecipeReviewAI.note(
        ["For \(bean.name).", why].filter { !$0.isEmpty }.joined(separator: " "),
        grind: review.grind, grinder: grinder)
      draft.grindSetting = RecipeReviewAI.wheelSetting(review.grind, grinder: grinder)
      picks.append(Pick(methodName: method.name, why: why, draft: draft, grind: review.grind))
    }
    guard !picks.isEmpty else { return nil }
    let summary = (answer["summary"] as? String ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return Outcome(summary: summary, picks: picks, source: source)
  }

  /// Saves the pick over the one this feature saved before with the same name and brewer.
  static func save(_ draft: RecipeDraft, store: Store) -> Result<Recipe, RecipeEditorError> {
    var draft = draft
    let recipes = (try? store.context.fetch(FetchDescriptor<Recipe>())) ?? []
    draft.sourceID =
      recipes.first {
        $0.credit == credit && $0.name == draft.name && $0.method?.id == draft.methodID
      }?.id
    return RecipeEditorService(store: store).save(draft)
  }

  static func ask(
    bean: Bean, goal: String, store: Store, grinder: String?,
    send: (AIRequestPayload) async throws -> (answer: [String: Any], source: String) = {
      try await DirectAI.send($0)
    }
  ) async throws -> Outcome {
    let methods = methods(store: store)
    guard !methods.isEmpty else { throw AIError.invalidResponse }
    let (answer, source) = try await send(
      payload(bean: bean, goal: goal, methods: methods, grinder: grinder))
    try Task.checkCancellation()
    guard
      let outcome = parse(answer, methods: methods, grinder: grinder, bean: bean, source: source)
    else { throw AIError.invalidResponse }
    return outcome
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
