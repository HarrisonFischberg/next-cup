import Foundation

/// What real recipes for a brewer look like: the numbers an AI is given before it writes a
/// recipe, and the limits its answer is checked against after.
///
/// Sources and assumptions: the limits are drawn wide around widely published recipes
/// (the makers' own guides for the V60, Chemex, Kalita Wave, Clever Dripper, AeroPress and
/// Bialetti Moka, and the Specialty Coffee Association's 1:15 to 1:18 brewing ratio), so
/// every built-in recipe passes at its own numbers (tested) and so does any recipe a careful
/// barista would write. A limit only catches a mistake: a 1:6 pour over, a 40 °C press, a
/// 20 second cold brew. The usual ranges are narrower and only ever guide a prompt.
struct BrewReference: Equatable {
  /// Grams of water (ice included) for each gram of coffee; for espresso, grams in the cup.
  var ratio: ClosedRange<Double>
  var usualRatio: ClosedRange<Double>
  /// Nil when the brewer, not the recipe, sets the temperature (cold brew, moka, machines).
  var tempC: ClosedRange<Double>?
  var usualTempC: ClosedRange<Double>?
  var timeS: ClosedRange<Int>
  var usualTimeS: ClosedRange<Int>
  /// One sentence on how the brewer is normally worked.
  var technique: String

  private static let cone = BrewReference(
    ratio: 13...19, usualRatio: 15...17, tempC: 80...100, usualTempC: 90...96,
    timeS: 105...360, usualTimeS: 150...210,
    technique:
      "Bloom with 2 to 3 times the coffee's weight for 30 to 45 s, then pour the rest in 2 to 4 pours."
  )
  private static let aeropress = BrewReference(
    ratio: 5...19, usualRatio: 12...16, tempC: 75...100, usualTempC: 85...95,
    timeS: 45...360, usualTimeS: 75...165,
    technique: "Pour, stir, steep 1 to 2 minutes, then press for about 30 s.")

  /// Keyed by `BrewMethod.builtInKey`. Nespresso has no entry and is held to its style.
  static let methods: [String: BrewReference] = [
    "cone-dripper": cone,
    "flat-dripper": BrewReference(
      ratio: 13...19, usualRatio: 15...17, tempC: 80...100, usualTempC: 90...96,
      timeS: 105...360, usualTimeS: 180...240, technique: cone.technique),
    "iced-pour-over": BrewReference(
      ratio: 13...19, usualRatio: 15...17, tempC: 80...100, usualTempC: 92...100,
      timeS: 105...360, usualTimeS: 150...210,
      technique:
        "Brew hot straight onto the ice: about 60% of the total is hot water and 40% is ice."),
    "chemex": BrewReference(
      ratio: 13...19, usualRatio: 15...17, tempC: 80...100, usualTempC: 92...96,
      timeS: 150...480, usualTimeS: 240...330,
      technique:
        "Bloom for 30 to 45 s, then 2 or 3 slow pours; the thick filter drains slowly."),
    "switchable-dripper": BrewReference(
      ratio: 13...19, usualRatio: 15...17, tempC: 80...100, usualTempC: 90...96,
      timeS: 120...420, usualTimeS: 165...240,
      technique:
        "Steep with the valve closed for 1 to 2 minutes, then open it to drain; a hybrid pours the rest over with the valve open."
    ),
    "press": BrewReference(
      ratio: 11...19, usualRatio: 14...17, tempC: 85...100, usualTempC: 93...96,
      timeS: 180...720, usualTimeS: 240...480,
      technique: "Pour all the water, steep 4 minutes or longer, then press gently."),
    "aeropress": aeropress,
    "inverted-press": aeropress,
    "espresso": BrewReference(
      ratio: 1...4, usualRatio: 1.5...2.5, tempC: 85...98, usualTempC: 90...95,
      timeS: 15...60, usualTimeS: 25...32,
      technique: "The water is the espresso in the cup, about twice the coffee's weight."),
    "moka-pot": BrewReference(
      ratio: 5...13, usualRatio: 8...10, tempC: nil, usualTempC: nil,
      timeS: 120...600, usualTimeS: 180...330,
      technique:
        "Fill the boiler to just under the valve and take it off the heat as it starts to sputter."
    ),
    "cold-brew": BrewReference(
      ratio: 4...18, usualRatio: 5...12, tempC: nil, usualTempC: nil,
      timeS: 14_400...86_400, usualTimeS: 43_200...64_800,
      technique:
        "Steep in the fridge or at room temperature, then filter; 1:5 to 1:8 makes a concentrate to dilute."
    ),
    "drip-machine": BrewReference(
      ratio: 13...19, usualRatio: 15...17, tempC: nil, usualTempC: nil,
      timeS: 180...900, usualTimeS: 240...360,
      technique: "Fill the reservoir, add the coffee to the basket and start the machine."),
  ]

  /// A brewer the user made has no key, so only its style is known and the limits are wider.
  /// Also what brew advice is held to when the taste the user typed names numbers.
  private static let styles: [BrewStyle: BrewReference] = [
    .pourOver: BrewReference(
      ratio: 12...20, usualRatio: 15...17, tempC: 80...100, usualTempC: 90...96,
      timeS: 90...600, usualTimeS: 150...240, technique: cone.technique),
    .immersion: BrewReference(
      ratio: 5...20, usualRatio: 13...17, tempC: 75...100, usualTempC: 88...96,
      timeS: 45...900, usualTimeS: 120...300,
      technique: "Pour all the water, steep, then separate the coffee from the grounds."),
    .espresso: BrewReference(
      ratio: 1...13, usualRatio: 1.5...2.5, tempC: nil, usualTempC: nil,
      timeS: 15...600, usualTimeS: 25...32, technique: ""),
    .cold: BrewReference(
      ratio: 4...20, usualRatio: 5...12, tempC: nil, usualTempC: nil,
      timeS: 3_600...86_400, usualTimeS: 43_200...64_800, technique: ""),
  ]

  static func find(methodKey: String?, style: BrewStyle?) -> BrewReference? {
    methodKey.flatMap { methods[$0] } ?? style.flatMap { styles[$0] }
  }

  /// Water for each gram of coffee, counting the ice of a recipe brewed over ice.
  static func ratio(of draft: RecipeDraft) -> Double? {
    guard draft.doseG > 0, draft.waterG > 0 else { return nil }
    return (draft.waterG + (draft.includesIce ? draft.iceG ?? 0 : 0)) / draft.doseG
  }

  // MARK: Prompt

  /// For the AI prompt: the usual numbers, the limits and how the brewer is worked. With a
  /// roast, the temperature is narrowed to the end of the range that roast wants.
  func promptLine(roast: RoastLevel? = nil) -> String {
    var parts = [
      "ratio usually \(Self.ratios(usualRatio)) and never outside \(Self.ratios(ratio)) "
        + "unless their note asks for it"
    ]
    if let usualTempC {
      var temp = "water at \(Self.number(usualTempC.lowerBound)) to "
      temp += "\(Self.number(usualTempC.upperBound)) °C"
      if let roast {
        temp += " (about \(Self.number(Self.temp(for: roast, in: usualTempC))) °C for this roast)"
      } else {
        temp += " (hotter for light roasts, cooler for dark)"
      }
      parts.append(temp)
    }
    parts.append(
      "done in \(Self.time(usualTimeS.lowerBound)) to \(Self.time(usualTimeS.upperBound))")
    let line = "What good recipes for this brewer use: " + parts.joined(separator: "; ") + "."
    return technique.isEmpty ? line : line + " " + technique
  }

  /// The same numbers in a few words, for a prompt that lists several brewers.
  var shortLine: String {
    var parts = ["usually \(Self.ratios(usualRatio))"]
    if let usualTempC {
      parts.append(
        "\(Self.number(usualTempC.lowerBound)) to \(Self.number(usualTempC.upperBound)) °C")
    }
    parts.append("\(Self.time(usualTimeS.lowerBound)) to \(Self.time(usualTimeS.upperBound))")
    return parts.joined(separator: ", ")
  }

  /// Light roasts extract best hot and dark roasts turn bitter there.
  static func temp(for roast: RoastLevel, in range: ClosedRange<Double>) -> Double {
    switch roast {
    case .ultraLight, .light: range.upperBound
    case .mediumLight, .medium: ((range.lowerBound + range.upperBound) / 2).rounded()
    case .mediumDark, .dark: range.lowerBound
    }
  }

  // MARK: Check

  /// What is wrong with the recipe's numbers, written for asking the AI again; nil when
  /// they are ones a real recipe uses. With `from` (the recipe or brew the AI started
  /// from), a number is only a problem when the AI moved it further outside than it
  /// already was, so the user's own numbers are never the mistake. `smallSteps` also
  /// limits how far the dose, water and temperature may move from `from` (a next cup
  /// changes a little at a time).
  func problem(_ draft: RecipeDraft, from: RecipeDraft? = nil, smallSteps: Bool = false)
    -> String?
  {
    var problems: [String] = []
    if let ratio = Self.ratio(of: draft),
      Self.gap(ratio, self.ratio)
        > max(0.05, from.flatMap(Self.ratio).map { Self.gap($0, self.ratio) } ?? 0)
    {
      problems.append(
        "its ratio is 1:\(Self.number(ratio, decimals: 1)) but recipes for this brewer stay "
          + "between \(Self.ratios(self.ratio))")
    }
    if let limits = tempC, let temp = draft.tempC,
      Self.gap(temp, limits) > (from?.tempC.map { Self.gap($0, limits) } ?? 0)
    {
      problems.append(
        "its water is \(Self.number(temp)) °C but this brewer is brewed between "
          + "\(Self.number(limits.lowerBound)) and \(Self.number(limits.upperBound)) °C")
    }
    let times = Double(timeS.lowerBound)...Double(timeS.upperBound)
    if let time = draft.totalTimeS,
      Self.gap(Double(time), times) > (from?.totalTimeS.map { Self.gap(Double($0), times) } ?? 0)
    {
      problems.append(
        "it takes \(Self.time(time)) but this brewer takes between "
          + "\(Self.time(timeS.lowerBound)) and \(Self.time(timeS.upperBound))")
    }
    if smallSteps, let from {
      if from.doseG > 0, abs(draft.doseG - from.doseG) > from.doseG * Self.mostChange {
        problems.append(
          "it changes the coffee from \(Self.number(from.doseG, decimals: 1)) g to "
            + "\(Self.number(draft.doseG, decimals: 1)) g, which is too big a step")
      }
      if from.waterG > 0, abs(draft.waterG - from.waterG) > from.waterG * Self.mostChange {
        problems.append(
          "it changes the water from \(Self.number(from.waterG)) g to "
            + "\(Self.number(draft.waterG)) g, which is too big a step")
      }
      if let before = from.tempC, let after = draft.tempC,
        abs(after - before) > Self.mostTempChangeC
      {
        problems.append(
          "it changes the temperature from \(Self.number(before)) to \(Self.number(after)) °C, "
            + "which is too big a step")
      }
    }
    guard !problems.isEmpty else { return nil }
    return "Your last recipe has numbers no good recipe for this brewer uses: "
      + problems.joined(separator: "; ") + ". Rewrite it with numbers inside those limits."
  }

  /// The recipe with its wrong numbers moved to the nearest ones this brewer is brewed
  /// with, and a sentence saying so; nil when it has no problem or cannot be mended. Only
  /// the coffee, the temperature and the finish time move, so every pour, and with it what
  /// the brewer holds, stays as written. A ratio so far out that the coffee would change by
  /// more than `mostMend` is not mended: that recipe is wrong in more than its numbers.
  func mended(_ draft: RecipeDraft, from: RecipeDraft? = nil, smallSteps: Bool = false)
    -> (draft: RecipeDraft, note: String)?
  {
    guard problem(draft, from: from, smallSteps: smallSteps) != nil else { return nil }
    var fixed = draft
    if let ratio = Self.ratio(of: draft), !self.ratio.contains(ratio) {
      // To the half gram just inside the limit.
      let water = ratio * draft.doseG
      let dose =
        ratio > self.ratio.upperBound
        ? (water / self.ratio.upperBound * 2).rounded(.up) / 2
        : (water / self.ratio.lowerBound * 2).rounded(.down) / 2
      guard abs(dose - draft.doseG) <= draft.doseG * Self.mostMend else { return nil }
      fixed.doseG = dose
    }
    if let limits = tempC, let temp = draft.tempC {
      fixed.tempC = min(max(temp, limits.lowerBound), limits.upperBound)
    }
    if let time = draft.totalTimeS, !timeS.contains(time) {
      let last = draft.steps.map(\.startOffsetS).max() ?? 0
      guard last < timeS.upperBound else { return nil }
      fixed.totalTimeS = min(max(time, timeS.lowerBound, last), timeS.upperBound)
    }
    guard problem(fixed, from: from, smallSteps: smallSteps) == nil else { return nil }
    return (
      fixed, "Its coffee, temperature or time was adjusted to what this brewer is brewed with."
    )
  }

  /// The most the coffee may change for a ratio to be mended rather than thrown away.
  static let mostMend = 0.25

  /// The most a next cup moves the dose or the water from the cup before it.
  static let mostChange = 0.25
  static let mostTempChangeC = 6.0

  /// How far outside the range; 0 inside it.
  private static func gap(_ value: Double, _ range: ClosedRange<Double>) -> Double {
    max(0, range.lowerBound - value, value - range.upperBound)
  }

  private static func ratios(_ range: ClosedRange<Double>) -> String {
    "1:\(number(range.lowerBound, decimals: 1)) to 1:\(number(range.upperBound, decimals: 1))"
  }

  private static func number(_ value: Double, decimals: Int = 0) -> String {
    value.rounded() == value || decimals == 0
      ? "\(Int(value.rounded()))" : String(format: "%.\(decimals)f", value)
  }

  /// "2:30" under an hour, "12 h" from there.
  private static func time(_ seconds: Int) -> String {
    seconds >= 3_600
      ? "\(number(Double(seconds) / 3_600, decimals: 1)) h"
      : "\(seconds / 60):" + String(format: "%02d", seconds % 60)
  }
}
