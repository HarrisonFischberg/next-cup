import Foundation
import NextCupKit
import SwiftData

/// Keeps stored suggestions in step: a newer brew of the same beans retires the older
/// unanswered one, and the next brew of a bean can find the one that belongs to it (X4).
@MainActor
struct SuggestionService {
  let store: Store

  /// A newer brew of the same beans makes an unanswered suggestion from an older
  /// one stale. It is dismissed so the list never offers two for one bean.
  func supersedeOlder(than brew: Brew, keeping fresh: Suggestion) {
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
}
