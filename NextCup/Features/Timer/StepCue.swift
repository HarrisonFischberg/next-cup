import NextCupKit

/// What the active brew tells you at each step, in plain commands worded for the brewer
/// in your hands: what to do now, how long your hands are busy, what to leave alone
/// after, and where the valve stands.
struct StepCue: Equatable {
  /// A steady kettle pours about this many grams a second; it sets how long "Pour now" lasts.
  static let pourGramsPerS = 5.0

  /// The command, e.g. "Close the valve, then pour to 270 g".
  var title: String
  /// How much to add. The recipe's own words stay on Start brew, under Show instructions.
  var detail: String?
  /// Seconds of hands-on work at the start of the step; nil means the whole step.
  var doS: Double?
  /// The chip while your hands are busy: "Pour now", "Watch the scale", "Do it now".
  var nowChip: String
  /// What to do once your hands are free, e.g. "Hands off. Let it steep".
  var waitTitle: String
  /// What should be true by now, e.g. "You should be at 150 g."
  var waitDetail: String?
  /// The valve after this step: nil when the brewer has no valve.
  var valveOpen: Bool?

  /// One step's words: the command (nil when the step is only waiting), seconds your
  /// hands are busy (nil for the whole step) and what to do once they are free.
  private struct Phrase {
    var command: String?
    var doS: Double?
    var after: String?
    var chip = "Do it now"
  }

  /// One cue per display group of `plan`. `kinds` are the recipe's step kinds by `order`;
  /// `method` is the built-in method key (or style) that sets the wording.
  static func cues(
    plan: TimerPlan, kinds: [String], method: String?, units: UnitPreferences
  ) -> [StepCue] {
    func kind(_ step: TimerStep) -> StepKind? {
      step.order < kinds.count ? StepKind(rawValue: kinds[step.order]) : nil
    }
    let all = plan.steps.compactMap(kind)
    let hasValve = all.contains { $0 == .openValve || $0 == .closeValve }
    let steeps = all.contains { [.wait, .press, .invert, .closeValve].contains($0) }
    // Brewers filled once rather than poured to a running weight.
    let fills = ["espresso", "moka-pot", "drip-machine"].contains(method ?? "")
    var water = 0.0
    var valveOpen = true
    // A bloom stays a bloom (through a stir or swirl) until the next pour.
    var blooming = false
    return plan.displayGroups.map { group in
      let steps = group.map { plan.steps[$0] }
      var commands: [String] = []
      var doS: Double? = 0
      var added = 0.0
      var after: String?
      var chip: String?
      for step in steps {
        let k = kind(step)
        var grams = 0.0
        if let target = step.targetCumulativeWaterG {
          grams = max(target - water, 0)
          added += grams
          water = target
          blooming = k == .bloom
        }
        if k == .openValve { valveOpen = true }
        if k == .closeValve { valveOpen = false }
        guard let k else {
          commands.append(step.label.lowercased())
          continue
        }
        let phrase = phrase(
          k, method: method, added: grams, water: water,
          weight: { RecipeFormat.weight($0, units) })
        if let command = phrase.command {
          // Two pours joined into one step (a short top-up) read as one pour to the later weight.
          if command.hasPrefix("pour to "), commands.last?.hasPrefix("pour to ") == true {
            commands.removeLast()
          }
          commands.append(command)
          chip = chip ?? phrase.chip
        }
        doS = phrase.doS.flatMap { s in doS.map { $0 + s } }
        after = phrase.after ?? after
      }
      let add: String? =
        switch method {
        case _ where added == 0: nil
        case "espresso": "Aim for \(RecipeFormat.weight(water, units)) in the cup."
        case _ where fills: nil
        default: "Add \(RecipeFormat.weight(added, units))."
        }
      let groupKinds = steps.compactMap(kind)
      let drains =
        groupKinds.contains(.drawdown)
        || ((hasValve ? valveOpen : !steeps) && !groupKinds.contains(.wait))
      let waitTitle =
        after
        ?? (blooming
          ? "Hands off. Let it bloom"
          : drains ? "Hands off. Let it drain" : "Hands off. Let it steep")
      let shouldBe: String? =
        switch method {
        case _ where water == 0: nil
        case "moka-pot", "drip-machine": nil
        case "espresso": "The cup should be at \(RecipeFormat.weight(water, units))."
        default: "You should be at \(RecipeFormat.weight(water, units))."
        }
      return StepCue(
        title: commands.isEmpty ? waitTitle : sentence(commands),
        detail: add,
        doS: commands.isEmpty ? 0 : doS, nowChip: chip ?? "Do it now",
        waitTitle: waitTitle, waitDetail: shouldBe,
        valveOpen: hasValve ? valveOpen : nil)
    }
  }

  /// The step as an order for this brewer, lower case so steps that start together join
  /// into one sentence.
  private static func phrase(
    _ kind: StepKind, method: String?, added: Double, water: Double,
    weight: (Double) -> String
  ) -> Phrase {
    let pourS = max(added / pourGramsPerS, 5)
    switch (kind, method) {
    case (.bloom, _):
      return Phrase(
        command: "pour to \(weight(water))", doS: pourS, after: "Hands off. Let it bloom",
        chip: "Pour now")
    case (.pour, "espresso"):
      return Phrase(command: "start the shot", doS: nil, chip: "Watch the scale")
    case (.pour, "moka-pot"):
      return Phrase(command: "fill the base with \(weight(added)) of water", doS: nil)
    case (.pour, "drip-machine"):
      return Phrase(command: "fill the reservoir with \(weight(added)) of water", doS: nil)
    case (.pour, "cold-brew"):
      return Phrase(
        command: "pour \(weight(added)) of cool water over the grounds", doS: pourS,
        chip: "Pour now")
    case (.pour, _):
      return Phrase(command: "pour to \(weight(water))", doS: pourS, chip: "Pour now")
    case (.bypass, _):
      return Phrase(
        command: "top up with \(weight(added)) of hot water", doS: pourS,
        after: "Done. Give it a stir and enjoy", chip: "Pour now")
    case (.closeValve, _): return Phrase(command: "close the valve", doS: 3)
    case (.openValve, _):
      return Phrase(command: "open the valve", doS: 3, after: "Hands off. Let it drain")
    case (.stir, _): return Phrase(command: "stir the grounds", doS: 10)
    case (.swirl, "iced-pour-over"):
      return Phrase(command: "swirl the carafe to melt the ice", doS: nil)
    case (.swirl, _): return Phrase(command: "swirl the brewer gently", doS: 5)
    case (.wait, "espresso"):
      return Phrase(command: "stop the shot at \(weight(water))", doS: nil)
    case (.wait, "moka-pot"):
      return Phrase(command: "watch the spout as the coffee rises", doS: nil, chip: "Watch it")
    case (.wait, "drip-machine"):
      return Phrase(command: nil, doS: 0, after: "Hands off. Wait until it stops dripping")
    case (.wait, "cold-brew"):
      return Phrase(command: "cover it", doS: 5, after: "Hands off. Let it steep")
    case (.wait, _): return Phrase(command: nil, doS: 0)
    case (.drawdown, _): return Phrase(command: nil, doS: 0, after: "Hands off. Let it drain")
    case (.invert, _): return Phrase(command: "fit the cap and flip it onto the cup", doS: 10)
    case (.press, "press"):
      return Phrase(command: "lower the plunger, then pour", doS: nil, chip: "Do it now")
    case (.press, _):
      return Phrase(command: "press the plunger down slowly", doS: nil, chip: "Press now")
    case (.plug, "inverted-press"):
      return Phrase(command: "push the plunger in a little, upside down", doS: 5)
    case (.plug, _): return Phrase(command: "set the plunger on top", doS: 5)
    case (.heat, _):
      return Phrase(
        command: "put it on the heat, lid open", doS: 5,
        after: "Hands off. Wait for the coffee to rise")
    case (.offHeat, _):
      return Phrase(command: "take it off the heat and cool the base", doS: nil)
    case (.brew, _):
      return Phrase(
        command: "start the machine", doS: 3, after: "Hands off. Let the machine brew")
    }
  }

  private static func sentence(_ parts: [String]) -> String {
    let joined = parts.joined(separator: ", then ")
    return joined.prefix(1).uppercased() + joined.dropFirst()
  }
}
