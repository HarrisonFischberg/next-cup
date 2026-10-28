import Foundation
import NextCupKit
import SwiftData

/// Turns AI brew diagnosis and insights into the same `Suggestion` cards the rules
/// make (T023). The model only picks a field, a new value and a reason; the old
/// value comes from the brew, and anything that does not validate stores nothing.
@MainActor
enum AISuggestions {
  /// Fields the model may change. Each has a value the brew form can take.
  static let fields: [BrewParameter] = [.grind, .water, .temperature, .time]

  static let schema = JSONSchema.object([
    "field": .string(allowed: fields.map(\.rawValue)),
    "toValue": .string(),
    "rationale": .string(),
  ])

  private static let schemaName = "dial_in_suggestion"

  private static let system = """
    You are a coffee brewing coach. Suggest exactly one change to try on the next brew. \
    Choose field from grind, water (grams), temperature (degrees Celsius) or time (seconds). \
    toValue is the new value: a number for water, temperature and time, a grind setting \
    in the user's own scale for grind. rationale is one or two plain sentences that use \
    only the brews given.
    """

  static func payload(diagnosing brew: Brew) -> AIRequestPayload {
    AIRequestPayload(
      system: system, userText: "Diagnose this brew.\n" + describe(brew),
      schemaName: schemaName, schema: schema)
  }

  /// Looks across several brews of one bean, newest first.
  static func payload(insightsFrom brews: [Brew]) -> AIRequestPayload {
    let recent = brews.sorted { $0.date > $1.date }.prefix(8)
    return AIRequestPayload(
      system: system,
      userText:
        "Find the pattern in these brews of the same coffee, newest first.\n"
        + recent.map(describe).joined(separator: "\n"),
      schemaName: schemaName, schema: schema)
  }

  private static func describe(_ brew: Brew) -> String {
    var parts = [brew.date.formatted(date: .abbreviated, time: .omitted)]
    if let method = brew.method { parts.append("method \(method.name)") }
    for bean in (brew.beans ?? []).compactMap(\.bean) {
      parts.append(
        "bean \([bean.originCountry, bean.process, bean.roastLevel?.rawValue].compactMap { $0 }.joined(separator: ", "))"
      )
    }
    if let value = brew.doseG { parts.append("dose \(SuggestionApplication.number(value)) g") }
    if let value = brew.waterG { parts.append("water \(SuggestionApplication.number(value)) g") }
    if let value = brew.grindSetting, !value.isEmpty { parts.append("grind \(value)") }
    if let value = brew.tempC {
      parts.append("temperature \(SuggestionApplication.number(value)) C")
    }
    if let value = brew.totalTimeS { parts.append("time \(value) s") }
    if !brew.verdicts.isEmpty {
      parts.append("tasted " + brew.verdicts.map(\.rawValue).joined(separator: " and "))
    }
    if let value = brew.ratingTenths { parts.append("rating \(Rating.text(value)) of 10") }
    if !brew.notes.isEmpty { parts.append("notes: \(brew.notes)") }
    return "- " + parts.joined(separator: "; ")
  }

  /// The brew's current value for a field, as canonical text.
  private static func current(_ field: BrewParameter, of brew: Brew) -> String {
    switch field {
    case .grind: brew.grindSetting ?? ""
    case .water: brew.waterG.map(SuggestionApplication.number) ?? ""
    case .temperature: brew.tempC.map(SuggestionApplication.number) ?? ""
    case .time: brew.totalTimeS.map(String.init) ?? ""
    default: ""
    }
  }

  private static func usable(_ text: String, for field: BrewParameter) -> Bool {
    switch field {
    case .grind: !text.isEmpty
    case .water: Double(text).map { $0 > 0 } ?? false
    case .temperature: Double(text) != nil
    case .time: Double(text).map { $0 >= 0 } ?? false
    default: false
    }
  }

  /// Makes the `Suggestion` for a finished diagnosis or insights request. The
  /// suggestion takes the request's id, so ingesting twice never doubles the card.
  @discardableResult
  static func ingest(_ request: AIRequest, in context: ModelContext) -> Result<Suggestion, AIError>
  {
    guard request.feature == .diagnosis || request.feature == .insights,
      request.status == .done, let brew = request.brew, let data = request.resultJSON,
      let object = try? JSONSerialization.jsonObject(with: data),
      schema.validates(object), let answer = object as? [String: Any],
      let field = (answer["field"] as? String).flatMap(BrewParameter.init(rawValue:)),
      let toValue = (answer["toValue"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
      let rationale = answer["rationale"] as? String, usable(toValue, for: field)
    else { return .failure(.invalidResponse) }

    let store = Store(context: context)
    if let existing = try? store.find(Suggestion.self, id: request.id) { return .success(existing) }

    let suggestion = Suggestion(id: request.id)
    suggestion.source = .ai
    suggestion.field = field
    suggestion.fromValue = current(field, of: brew)
    suggestion.toValue = toValue
    suggestion.rationale = rationale
    suggestion.modelID = request.modelID
    context.insert(suggestion)
    suggestion.sourceBrew = brew
    SuggestionService(store: store).supersedeOlder(than: brew, keeping: suggestion)
    guard case .success = store.save() else {
      context.rollback()
      return .failure(.invalidResponse)
    }
    return .success(suggestion)
  }
}
