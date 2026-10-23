import Foundation

/// How a cup tasted. Mirrors the app's stored verdict by raw value.
public enum DialInVerdict: String, Codable, CaseIterable, Sendable {
  case sour, bitter, weak, strong, balanced
}

/// The brewing family, which decides which levers make sense. Mirrors the app's
/// brew style by raw value.
public enum DialInStyle: String, Codable, CaseIterable, Sendable {
  case pourOver, immersion, espresso, cold
}

/// The one thing a suggestion changes. Raw values match the app's brew parameters.
public enum DialInParameter: String, Codable, CaseIterable, Sendable {
  case grind, water, yield, temperature, time
}

/// What the rules look at: the verdict and the values the cup was brewed with,
/// in canonical units (grams, °C, seconds).
public struct DialInInput: Equatable, Sendable {
  public var verdict: DialInVerdict
  public var style: DialInStyle
  /// The parameters the brew's method tracks. A change is only proposed on a
  /// parameter the form actually shows.
  public var tracked: Set<DialInParameter>
  public var grindSetting: String?
  public var waterG: Double?
  public var tempC: Double?
  public var totalTimeS: Int?

  public init(
    verdict: DialInVerdict, style: DialInStyle, tracked: Set<DialInParameter>,
    grindSetting: String? = nil, waterG: Double? = nil, tempC: Double? = nil,
    totalTimeS: Int? = nil
  ) {
    self.verdict = verdict
    self.style = style
    self.tracked = tracked
    self.grindSetting = grindSetting
    self.waterG = waterG
    self.tempC = tempC
    self.totalTimeS = totalTimeS
  }
}

/// One proposed change. `fromValue` and `toValue` are canonical text (grind as
/// typed, water and yield in grams, temperature in °C, time in seconds); the app
/// formats them for the user's units.
public struct SuggestionDraft: Equatable, Sendable {
  public var parameter: DialInParameter
  public var fromValue: String
  public var toValue: String
  public var rationale: String

  public init(
    parameter: DialInParameter, fromValue: String, toValue: String, rationale: String
  ) {
    self.parameter = parameter
    self.fromValue = fromValue
    self.toValue = toValue
    self.rationale = rationale
  }
}

public enum DialInOutcome: Equatable, Sendable {
  /// Change this one thing before the next cup.
  case change(SuggestionDraft)
  /// Nothing to change: the cup was right, or no tracked lever applies.
  case keep(String)
}

/// Rule-based dial-in: from how a cup tasted, one change to try next. One lever at
/// a time, so the next cup shows what the change did.
public enum DialInRules {
  public static let temperatureStepC = 2.0
  public static let temperatureCeilingC = 99.0
  public static let temperatureFloorC = 80.0
  public static let immersionTimeStepS = 30
  public static let coldTimeStepS = 7_200
  public static let coldTimeFloorS = 3_600
  /// Share of the water or yield to move when a cup was weak or strong.
  public static let weakCut = 0.06
  public static let strongAdd = 0.08
  public static let espressoYieldShift = 0.10

  public static func suggest(for input: DialInInput) -> DialInOutcome {
    switch input.verdict {
    case .balanced:
      return .keep("This cup was balanced. Brew it again the same way.")
    case .sour:
      return firstChange(
        [grind(input, finer: true), temperature(input, warmer: true), time(input, longer: true)],
        verdict: input.verdict)
    case .bitter:
      return firstChange(
        [
          grind(input, finer: false), temperature(input, warmer: false), time(input, longer: false),
        ],
        verdict: input.verdict)
    case .weak:
      return firstChange([strength(input, stronger: true)], verdict: input.verdict)
    case .strong:
      return firstChange([strength(input, stronger: false)], verdict: input.verdict)
    }
  }

  private static func firstChange(_ options: [SuggestionDraft?], verdict: DialInVerdict)
    -> DialInOutcome
  {
    if let change = options.compactMap({ $0 }).first { return .change(change) }
    return .keep("No setting for this \(verdict.rawValue) cup can be changed from here.")
  }

  // MARK: Levers

  private static func grind(_ input: DialInInput, finer: Bool) -> SuggestionDraft? {
    guard input.tracked.contains(.grind) else { return nil }
    let why =
      finer
      ? "Sour usually means the coffee was under-extracted. A finer grind slows the water and pulls more out."
      : "Bitter usually means the coffee was over-extracted. A coarser grind lets the water through faster and pulls less out."
    let current = input.grindSetting?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if let moved = GrindStep.moved(current, finer: finer) {
      return SuggestionDraft(
        parameter: .grind, fromValue: current, toValue: moved,
        rationale: why + " On most grinders a lower number is finer.")
    }
    return SuggestionDraft(
      parameter: .grind, fromValue: current, toValue: finer ? "one step finer" : "one step coarser",
      rationale: why)
  }

  private static func temperature(_ input: DialInInput, warmer: Bool) -> SuggestionDraft? {
    guard input.tracked.contains(.temperature), input.style != .cold, input.style != .espresso,
      let current = input.tempC
    else { return nil }
    let next =
      warmer
      ? min(current + temperatureStepC, temperatureCeilingC)
      : max(current - temperatureStepC, temperatureFloorC)
    guard next != current else { return nil }
    let why =
      warmer
      ? "Hotter water extracts more, which helps a sour cup."
      : "Cooler water extracts less, which calms a bitter cup."
    return SuggestionDraft(
      parameter: .temperature, fromValue: number(current), toValue: number(next), rationale: why)
  }

  private static func time(_ input: DialInInput, longer: Bool) -> SuggestionDraft? {
    guard input.tracked.contains(.time), let current = input.totalTimeS else { return nil }
    let next: Int
    switch input.style {
    case .immersion:
      next = max(60, current + (longer ? immersionTimeStepS : -immersionTimeStepS))
    case .cold:
      next = max(coldTimeFloorS, current + (longer ? coldTimeStepS : -coldTimeStepS))
    case .pourOver, .espresso:
      return nil
    }
    guard next != current else { return nil }
    let why =
      longer
      ? "A longer steep extracts more, which helps a sour cup."
      : "A shorter steep extracts less, which calms a bitter cup."
    return SuggestionDraft(
      parameter: .time, fromValue: String(current), toValue: String(next), rationale: why)
  }

  /// Weak and strong are about concentration. Espresso moves the output weight,
  /// everything else moves the water.
  private static func strength(_ input: DialInInput, stronger: Bool) -> SuggestionDraft? {
    guard let current = input.waterG, current > 0 else { return nil }
    let isEspresso = input.style == .espresso
    let share =
      isEspresso ? espressoYieldShift : (stronger ? weakCut : strongAdd)
    let factor = stronger ? 1 - share : 1 + share
    let next = isEspresso ? roundToHalf(current * factor) : (current * factor).rounded()
    guard next != current, next > 0 else { return nil }
    let amount = isEspresso ? "output weight" : "water"
    let why =
      stronger
      ? "A weak cup is too dilute. Less \(amount) for the same coffee makes it stronger."
      : "A strong cup is too concentrated. More \(amount) for the same coffee makes it lighter."
    return SuggestionDraft(
      parameter: isEspresso ? .yield : .water, fromValue: number(current), toValue: number(next),
      rationale: why)
  }

  private static func roundToHalf(_ value: Double) -> Double { (value * 2).rounded() / 2 }

  /// Whole numbers without a trailing ".0", otherwise one decimal.
  static func number(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
  }
}

/// Moves a typed grind setting one step, keeping whatever text surrounds the
/// number ("21 clicks" becomes "20 clicks").
enum GrindStep {
  static func moved(_ setting: String, finer: Bool) -> String? {
    let scanner = Scanner(string: setting)
    scanner.charactersToBeSkipped = nil
    guard let value = scanner.scanDouble() else { return nil }
    let rest = setting[scanner.currentIndex...]
    let next = finer ? value - 1 : value + 1
    guard next >= 0 else { return nil }
    return DialInRules.number(next) + rest
  }
}
