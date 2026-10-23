import Foundation
import NextCupKit
import SwiftData

/// Stores the dial-in suggestions the rules make from a saved brew and finds the
/// one that belongs on the next brew of the same bean (X4).
@MainActor
struct SuggestionService {
  let store: Store

  /// Makes the rules suggestion for a saved brew, replacing one that was never
  /// answered. A brew that already has an answered suggestion keeps it (editing a
  /// brew never rewrites what the user decided). A balanced cup, or a cup with
  /// nothing to change, stores nothing and returns the reason in `.keep`.
  func propose(for brew: Brew) -> Result<DialInOutcome, StoreError> {
    let made = (brew.suggestionsMade ?? []).filter { $0.source == .rules }
    if made.contains(where: { $0.state != .proposed }) {
      return .success(.keep("This brew already has a suggestion you answered."))
    }
    for old in made { store.context.delete(old) }

    guard let verdict = brew.verdict.flatMap({ DialInVerdict(rawValue: $0.rawValue) }) else {
      return commit(.keep("Choose how it tasted to get a suggestion."))
    }
    let outcome = DialInRules.suggest(for: input(for: brew, verdict: verdict))
    guard case .change(let change) = outcome else { return commit(outcome) }

    let suggestion = Suggestion()
    suggestion.source = .rules
    suggestion.field = BrewParameter(rawValue: change.parameter.rawValue) ?? .grind
    suggestion.fromValue = change.fromValue
    suggestion.toValue = change.toValue
    suggestion.rationale = change.rationale
    suggestion.state = .proposed
    store.context.insert(suggestion)
    suggestion.sourceBrew = brew
    supersedeOlder(than: brew, keeping: suggestion)
    return commit(outcome)
  }

  private func commit(_ outcome: DialInOutcome) -> Result<DialInOutcome, StoreError> {
    switch store.save() {
    case .success: return .success(outcome)
    case .failure(let error):
      store.context.rollback()
      return .failure(error)
    }
  }

  private func input(for brew: Brew, verdict: DialInVerdict) -> DialInInput {
    let shown =
      brew.method.map { MethodParameters.shown(tracked: $0.trackedParameters) }
      ?? Set(BrewParameter.allCases)
    let tracked = Set(shown.compactMap { DialInParameter(rawValue: $0.rawValue) })
    let style = brew.method.flatMap { DialInStyle(rawValue: $0.style.rawValue) } ?? .pourOver
    return DialInInput(
      verdict: verdict, style: style, tracked: tracked, grindSetting: brew.grindSetting,
      waterG: brew.waterG, tempC: brew.tempC, totalTimeS: brew.totalTimeS)
  }

  /// A newer brew of the same beans makes an unanswered suggestion from an older
  /// one stale. It is dismissed so the list never offers two for one bean.
  private func supersedeOlder(than brew: Brew, keeping fresh: Suggestion) {
    let all = (try? store.context.fetch(FetchDescriptor<Suggestion>())) ?? []
    for other in all where other.id != fresh.id && other.state == .proposed {
      guard let source = other.sourceBrew, source.id != brew.id, source.date <= brew.date,
        Self.sameBeans(source, brew)
      else { continue }
      other.state = .dismissed
      other.updatedAt = Date()
    }
  }

  private static func beanIDs(_ brew: Brew) -> Set<UUID> {
    Set((brew.beans ?? []).compactMap { $0.bean?.id })
  }

  /// Brews share beans when any bean is common; two brews with no beans share a
  /// method instead.
  private static func sameBeans(_ first: Brew, _ second: Brew) -> Bool {
    let a = beanIDs(first)
    let b = beanIDs(second)
    if a.isEmpty && b.isEmpty { return first.method?.id == second.method?.id }
    return !a.isDisjoint(with: b)
  }

  /// The newest unanswered suggestion for a brew that is about to be made with
  /// these beans (or, with no beans, this method). The brew itself never matches.
  static func match(
    in suggestions: [Suggestion], beanIDs: Set<UUID>, methodID: UUID?, excluding brewID: UUID
  ) -> Suggestion? {
    suggestions
      .filter { $0.state == .proposed }
      .sorted { $0.createdAt > $1.createdAt }
      .first { suggestion in
        guard let source = suggestion.sourceBrew, source.id != brewID else { return false }
        let sourceBeans = Self.beanIDs(source)
        if beanIDs.isEmpty && sourceBeans.isEmpty { return source.method?.id == methodID }
        return !beanIDs.isEmpty && !beanIDs.isDisjoint(with: sourceBeans)
      }
  }
}

/// Reads and writes the brew-form value a suggestion is about.
enum SuggestionApplication {
  /// The draft's current value as canonical text; empty when nothing is set.
  static func value(of parameter: BrewParameter, in draft: BrewDraft) -> String {
    switch parameter {
    case .grind: draft.grindSetting
    case .water, .yield: draft.waterG.map(number) ?? ""
    case .temperature: draft.tempC.map(number) ?? ""
    case .time: draft.totalTimeS.map(String.init) ?? ""
    case .dose, .tds, .rating, .notes, .photo: ""
    }
  }

  /// Puts canonical text into the draft. Returns `false` when the text is not a
  /// usable value for that field, leaving the draft unchanged.
  @discardableResult
  static func set(_ text: String, for parameter: BrewParameter, in draft: inout BrewDraft) -> Bool {
    let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
    switch parameter {
    case .grind:
      draft.grindSetting = clean
      return true
    case .water, .yield:
      guard let value = Double(clean), value > 0 else { return false }
      draft.waterG = value
      return true
    case .temperature:
      guard let value = Double(clean) else { return false }
      draft.tempC = value
      return true
    case .time:
      guard let value = Double(clean), value >= 0 else { return false }
      draft.totalTimeS = Int(value.rounded())
      return true
    case .dose, .tds, .rating, .notes, .photo:
      return false
    }
  }

  static func number(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
  }
}

/// Display strings for a suggestion, in the user's units. Stored values stay
/// canonical.
enum SuggestionFormat {
  static func title(_ parameter: BrewParameter) -> String {
    switch parameter {
    case .grind: "Grind"
    case .water: "Water"
    case .yield: "Output weight"
    case .temperature: "Temperature"
    case .time: "Time"
    default: MethodParameters.title(parameter)
    }
  }

  /// One stored value as the user reads it.
  static func display(_ text: String, for parameter: BrewParameter, _ units: UnitPreferences)
    -> String
  {
    let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if clean.isEmpty { return "not set" }
    switch parameter {
    case .water, .yield: return Double(clean).map { RecipeFormat.weight($0, units) } ?? clean
    case .temperature: return Double(clean).map { RecipeFormat.temperature($0, units) } ?? clean
    case .time: return Double(clean).map { RecipeFormat.clock(Int($0)) } ?? clean
    default: return clean
    }
  }

  /// "Grind: 20 → 19".
  static func headline(_ suggestion: Suggestion, _ units: UnitPreferences) -> String {
    let field = suggestion.field
    return
      "\(title(field)): \(display(suggestion.fromValue, for: field, units)) → \(display(suggestion.toValue, for: field, units))"
  }

  /// "Grind from 20 to 19", for VoiceOver.
  static func spoken(_ suggestion: Suggestion, _ units: UnitPreferences) -> String {
    let field = suggestion.field
    return
      "\(title(field)) from \(display(suggestion.fromValue, for: field, units)) to \(display(suggestion.toValue, for: field, units))"
  }

  static func title(_ state: SuggestionState) -> String {
    switch state {
    case .proposed: "Waiting"
    case .accepted: "Applied"
    case .edited: "Applied, edited"
    case .dismissed: "Dismissed"
    }
  }

  /// What the edit field shows: the stored value in the user's unit.
  static func editable(_ text: String, for parameter: BrewParameter, _ units: UnitPreferences)
    -> String
  {
    let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
    switch parameter {
    case .water, .yield:
      return Double(clean).map { RecipeFormat.weight($0, units, withSymbol: false) } ?? clean
    case .temperature:
      return Double(clean).map { String(format: "%.0f", units.displayTemperature(celsius: $0)) }
        ?? clean
    default: return clean
    }
  }

  /// Turns what the user typed (in their unit) back into canonical text, or `nil`
  /// when it is not a usable value.
  static func canonical(_ typed: String, for parameter: BrewParameter, _ units: UnitPreferences)
    -> String?
  {
    let clean = typed.trimmingCharacters(in: .whitespacesAndNewlines)
    switch parameter {
    case .grind:
      return clean.isEmpty ? nil : clean
    case .water, .yield:
      guard let value = Double(clean), value > 0 else { return nil }
      return SuggestionApplication.number(
        (units.grams(fromDisplayWeight: value) * 10).rounded() / 10)
    case .temperature:
      guard let value = Double(clean) else { return nil }
      return SuggestionApplication.number(units.celsius(fromDisplayTemperature: value).rounded())
    case .time:
      guard let value = Double(clean), value >= 0 else { return nil }
      return String(Int(value.rounded()))
    default:
      return nil
    }
  }
}
