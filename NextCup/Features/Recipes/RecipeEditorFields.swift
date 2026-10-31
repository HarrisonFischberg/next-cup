import Foundation
import NextCupKit

/// The editor's text fields, in the user's units. Typing stays free-form; this
/// turns the text into a `RecipeDraft` (grams, °C, seconds) only on Save, and
/// reports the field it could not read instead of guessing.
struct RecipeEditorFields: Equatable {
  struct StepFields: Identifiable, Equatable {
    var id = UUID()
    var kind: StepKind = .pour
    var time = ""
    var water = ""
    var instruction = ""
  }

  var sourceID: UUID?
  var name = ""
  var methodID: UUID?
  var credit = ""
  var creditURL: URL?
  var dose = ""
  var water = ""
  var temperature = ""
  var time = ""
  var includesIce = false
  var ice = ""
  var tuningNote = ""
  /// Not shown as a field; kept so Save writes the AI's grind back.
  var grindSetting: String?
  var grinderName: String?
  var steps: [StepFields] = []

  init() {}

  init(draft: RecipeDraft, units: UnitPreferences) {
    sourceID = draft.sourceID
    name = draft.name
    methodID = draft.methodID
    credit = draft.credit ?? ""
    creditURL = draft.creditURL
    dose = Self.weightText(draft.doseG, units)
    water = Self.weightText(draft.waterG, units)
    temperature =
      draft.tempC.map { Self.numberText(units.displayTemperature(celsius: $0), 0) } ?? ""
    time = draft.totalTimeS.map(RecipeFormat.clock) ?? ""
    includesIce = draft.includesIce
    ice = draft.iceG.map { Self.weightText($0, units) } ?? ""
    tuningNote = draft.tuningNote ?? ""
    (grindSetting, grinderName) = (draft.grindSetting, draft.grinderName)
    steps = draft.steps.map {
      StepFields(
        id: $0.id, kind: $0.kind, time: RecipeFormat.clock($0.startOffsetS),
        water: $0.targetCumulativeWaterG.map { Self.weightText($0, units) } ?? "",
        instruction: $0.instruction)
    }
  }

  func draft(units: UnitPreferences) -> Result<RecipeDraft, RecipeEditorError> {
    func number(_ text: String, _ field: String) -> Result<Double?, RecipeEditorError> {
      let trimmed = text.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty { return .success(nil) }
      guard let value = Self.parseNumber(trimmed) else {
        return .failure(.unreadable(field: field))
      }
      return .success(value)
    }
    func seconds(_ text: String, _ field: String) -> Result<Int?, RecipeEditorError> {
      let trimmed = text.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty { return .success(nil) }
      guard let value = Self.parseClock(trimmed) else { return .failure(.unreadable(field: field)) }
      return .success(value)
    }

    do {
      var draft = RecipeDraft()
      draft.sourceID = sourceID
      draft.name = name
      draft.methodID = methodID
      draft.credit = credit
      draft.creditURL = creditURL
      draft.doseG = try number(dose, "Dose").get().map(units.grams(fromDisplayWeight:)) ?? 0
      draft.waterG = try number(water, "Water").get().map(units.grams(fromDisplayWeight:)) ?? 0
      draft.tempC = try number(temperature, "Temperature").get().map(
        units.celsius(fromDisplayTemperature:))
      draft.totalTimeS = try seconds(time, "Time").get()
      draft.includesIce = includesIce
      draft.iceG = try number(ice, "Ice").get().map(units.grams(fromDisplayWeight:))
      draft.tuningNote = tuningNote
      (draft.grindSetting, draft.grinderName) = (grindSetting, grinderName)
      for (index, step) in steps.enumerated() {
        var out = RecipeStepDraft(id: step.id, kind: step.kind)
        out.startOffsetS = try seconds(step.time, "Step \(index + 1) time").get() ?? 0
        out.targetCumulativeWaterG = try number(step.water, "Step \(index + 1) water").get().map(
          units.grams(fromDisplayWeight:))
        out.instruction = step.instruction
        draft.steps.append(out)
      }
      return .success(draft)
    } catch let error as RecipeEditorError {
      return .failure(error)
    } catch {
      return .failure(.saveFailed(error.localizedDescription))
    }
  }

  // MARK: Parsing and printing

  /// "18", "18.5" and "18,5" all read; anything else does not.
  static func parseNumber(_ text: String) -> Double? {
    let value = Double(text.replacingOccurrences(of: ",", with: "."))
    guard let value, value.isFinite, value >= 0 else { return nil }
    return value
  }

  /// "3:05" or plain seconds ("185").
  static func parseClock(_ text: String) -> Int? {
    let parts = text.split(separator: ":", omittingEmptySubsequences: false)
    switch parts.count {
    case 1: return Int(parts[0]).flatMap { $0 >= 0 ? $0 : nil }
    case 2:
      guard let minutes = Int(parts[0]), let rest = Int(parts[1]), minutes >= 0,
        (0..<60).contains(rest)
      else { return nil }
      return minutes * 60 + rest
    default: return nil
    }
  }

  /// Grams as whole or one-decimal numbers; ounces to three decimals. Parsing the
  /// text back gives the same grams to within display rounding.
  private static func weightText(_ grams: Double, _ units: UnitPreferences) -> String {
    let value = units.displayWeight(grams: grams)
    return numberText(value, units.weight == .grams ? 1 : 3)
  }

  private static func numberText(_ value: Double, _ decimals: Int) -> String {
    var text = String(format: "%.\(decimals)f", value)
    if text.contains(".") {
      while text.hasSuffix("0") { text.removeLast() }
      if text.hasSuffix(".") { text.removeLast() }
    }
    return text
  }
}
