import NextCupKit

/// What the active brew tells you at each step, in plain commands: what to do now, how
/// long your hands are busy, what to leave alone after, and where the valve stands.
struct StepCue: Equatable {
  /// A steady kettle pours about this many grams a second; it sets how long "Pour now" lasts.
  static let pourGramsPerS = 5.0

  /// The command, e.g. "Close the valve, then pour to 270 g".
  var title: String
  /// How much to add and the recipe's own words.
  var detail: String?
  /// Seconds of hands-on work at the start of the step; nil means the whole step.
  var doS: Double?
  /// True when the step adds water, so the chip says "Pour now".
  var pours: Bool
  /// What to do once your hands are free, e.g. "Let it steep".
  var waitTitle: String
  /// What should be true by now, e.g. "You should be at 150 g."
  var waitDetail: String?
  /// The valve after this step: nil when the brewer has no valve.
  var valveOpen: Bool?

  /// One cue per display group of `plan`. `kinds` are the recipe's step kinds by `order`.
  static func cues(plan: TimerPlan, kinds: [String], units: UnitPreferences) -> [StepCue] {
    func kind(_ step: TimerStep) -> StepKind? {
      step.order < kinds.count ? StepKind(rawValue: kinds[step.order]) : nil
    }
    let all = plan.steps.compactMap(kind)
    let hasValve = all.contains { $0 == .openValve || $0 == .closeValve }
    let steeps = all.contains { [.wait, .press, .invert, .closeValve].contains($0) }
    var water = 0.0
    var valveOpen = true
    return plan.displayGroups.map { group in
      let steps = group.map { plan.steps[$0] }
      var commands: [String] = []
      var doS: Double? = 0
      var added = 0.0
      for step in steps {
        let k = kind(step)
        let target = step.targetCumulativeWaterG
        if let target, k != .wait {
          let grams = max(target - water, 0)
          added += grams
          water = target
          commands.append(
            k == .bypass
              ? "add water to \(RecipeFormat.weight(target, units))"
              : "pour to \(RecipeFormat.weight(target, units))")
          doS = doS.map { $0 + max(grams / pourGramsPerS, 5) }
          continue
        }
        if k == .openValve { valveOpen = true }
        if k == .closeValve { valveOpen = false }
        guard let k else {
          commands.append(step.label.lowercased())
          continue
        }
        if let words = command(k) { commands.append(words) }
        switch k {
        case .press, .heat, .brew: doS = nil
        case .wait, .drawdown, .offHeat: break
        default: doS = doS.map { $0 + handsOnS(k) }
        }
      }
      let words = steps.map(\.instruction).filter { !$0.isEmpty }.joined(separator: " ")
      let add = added > 0 ? "Add \(RecipeFormat.weight(added, units))." : nil
      let title =
        commands.isEmpty ? steps.map(\.label).joined(separator: " & ") : sentence(commands)
      let groupKinds = steps.compactMap(kind)
      let drains =
        groupKinds.contains(.drawdown)
        || ((hasValve ? valveOpen : !steeps) && !groupKinds.contains(.wait))
      // The valve has its own badge on screen, so the words stay on the water.
      let state = water > 0 ? "You should be at \(RecipeFormat.weight(water, units))." : ""
      return StepCue(
        title: title,
        detail: [add, words.isEmpty ? nil : words].compactMap { $0 }.joined(separator: " ")
          .nilIfEmpty,
        doS: doS, pours: added > 0,
        waitTitle: drains ? "Hands off. Let it drain" : "Hands off. Let it steep",
        waitDetail: state.nilIfEmpty,
        valveOpen: hasValve ? valveOpen : nil)
    }
  }

  /// The step as an order, lower case so steps that start together join into one sentence.
  private static func command(_ kind: StepKind) -> String? {
    switch kind {
    case .closeValve: "close the valve"
    case .openValve: "open the valve"
    case .stir: "stir"
    case .swirl: "swirl"
    case .wait: "wait"
    case .drawdown: "let it drain"
    case .invert: "flip it onto the cup"
    case .press: "press the plunger down"
    case .plug: "insert the plunger"
    case .heat: "heat it"
    case .offHeat: "take it off the heat"
    case .brew: "start the brew"
    case .bloom, .pour, .bypass: nil
    }
  }

  /// Rough seconds each hands-on action takes, so the chip turns to "Hands off" after it.
  private static func handsOnS(_ kind: StepKind) -> Double {
    switch kind {
    case .openValve, .closeValve: 3
    case .swirl, .plug: 5
    default: 10
    }
  }

  private static func sentence(_ parts: [String]) -> String {
    let joined = parts.joined(separator: ", then ")
    return joined.prefix(1).uppercased() + joined.dropFirst()
  }
}

extension String {
  fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
