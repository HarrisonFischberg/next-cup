import Foundation

/// The rules every brew passes before it is shown or timed, whoever wrote the recipe (built
/// in, the user, an AI) and however it was sized. The recipe says what to brew; the engine
/// makes sure it can be brewed as written: it fits the brewer, no pour is too small to pour,
/// and every pour has time before the next step. A recipe that already passes comes back
/// unchanged, and every built-in recipe passes at its own size (tested).
///
/// To teach Next Cup something new about brewing, add a rule here: a function from a draft to
/// a changed draft and a sentence saying what changed, run from `plan`.
@MainActor
enum BrewEngine {
  struct Plan {
    var draft: RecipeDraft
    /// What was changed, one sentence each; empty when the recipe passed as written.
    var notes: [String] = []
    var note: String? { notes.isEmpty ? nil : notes.joined(separator: " ") }
  }

  /// A pour smaller than this share of the dose is not worth a step (a bloom is 2 to 3 times
  /// the dose).
  static let leastPourPerDose = 0.5
  /// The floor and ceiling of that smallest pour, in grams.
  static let leastPourRangeG = 10.0...BrewerFit.leastPourG
  /// The fastest water goes in: a kettle emptied into a press. Slower pours are the
  /// recipe's business; this only catches a pour with no time at all.
  static let fastestPourGPerS = 60.0
  static let leastPourS = 5

  /// `draft` as it will be brewed on the method `methodKey`. `fits` off skips the brewer's
  /// capacity (the timer, once it has already taken the dose down to fit).
  static func plan(
    _ draft: RecipeDraft, methodKey: String?, fits: Bool = true,
    defaults: UserDefaults = .standard
  ) -> Plan {
    let brewer = BrewerFit.current(methodKey, defaults: defaults)
    var plan = Plan(draft: draft)
    if fits, let fitted = brewer?.fitted(draft) {
      plan.draft = fitted.draft
      plan.notes.append(fitted.note)
    }
    for rule in [foldSmallPours, givePoursTime] {
      if let (changed, note) = rule(plan.draft, brewer) {
        plan.draft = changed
        plan.notes.append(note)
      }
    }
    return plan
  }

  static func leastPourG(doseG: Double) -> Double {
    min(leastPourRangeG.upperBound, max(leastPourRangeG.lowerBound, doseG * leastPourPerDose))
  }

  /// A pour too small to pour joins the pour before it, or the one after when the brewer
  /// could not hold it then. Blooms are left alone, and so is a small pour with nowhere to go.
  static func foldSmallPours(_ draft: RecipeDraft, brewer: BrewerFit?) -> (RecipeDraft, String)? {
    let least = leastPourG(doseG: draft.doseG)
    var steps = RecipeEditorService.sorted(draft.steps)
    var folded = false
    var index = 0
    while index < steps.count {
      defer { index += 1 }
      guard steps[index].kind == .pour, let target = steps[index].targetCumulativeWaterG else {
        continue
      }
      let before = steps[..<index].compactMap(\.targetCumulativeWaterG).max() ?? 0
      guard target - before > 0, target - before < least else { continue }
      func fits(_ candidate: [RecipeStepDraft]) -> Bool {
        var trial = draft
        trial.steps = candidate
        return brewer?.overfills(trial).isEmpty ?? true
      }
      var without = steps
      without.remove(at: index)
      // Targets are running totals, so the pour before takes this one's total...
      var intoBefore = without
      if let earlier = intoBefore[..<index].lastIndex(where: {
        ($0.kind == .pour || $0.kind == .bloom) && $0.targetCumulativeWaterG != nil
      }) {
        intoBefore[earlier].targetCumulativeWaterG = target
        intoBefore[earlier].instruction = retargeted(intoBefore[earlier].instruction, to: target)
        if fits(intoBefore) {
          steps = intoBefore
          folded = true
          index -= 1
          continue
        }
      }
      // ...and with the step gone, the pour after already reaches its own.
      let later = without[index...].first { $0.kind == .pour && $0.targetCumulativeWaterG != nil }
      if let later, fits(without) {
        if let at = without.firstIndex(where: { $0.id == later.id }),
          let total = later.targetCumulativeWaterG
        {
          without[at].instruction = retargeted(later.instruction, to: total)
        }
        steps = without
        folded = true
        index -= 1
      }
    }
    guard folded else { return nil }
    var fixed = draft
    fixed.steps = steps
    return (fixed, "A pour too small to pour was folded into the pour beside it.")
  }

  /// A pour's words name grams that no longer hold once it takes in another pour.
  private static func retargeted(_ instruction: String, to total: Double) -> String {
    instruction.contains(/\d\s?g\b/) ? "Pour to \(BrewerFit.grams(total)) g." : instruction
  }

  /// Every pour gets time before the step after it; the steps after move later to make it.
  static func givePoursTime(_ draft: RecipeDraft, brewer: BrewerFit?) -> (RecipeDraft, String)? {
    var steps = RecipeEditorService.sorted(draft.steps)
    var delay = 0
    var poured = 0.0
    for index in steps.indices {
      steps[index].startOffsetS += delay
      guard steps[index].kind == .pour || steps[index].kind == .bloom,
        let target = steps[index].targetCumulativeWaterG
      else { continue }
      let added = max(0, target - poured)
      poured = max(poured, target)
      guard added > 0, index + 1 < steps.count else { continue }
      let needs = max(leastPourS, Int((added / fastestPourGPerS).rounded(.up)))
      let has = steps[index + 1].startOffsetS + delay - steps[index].startOffsetS
      delay += max(0, needs - has)
    }
    guard delay > 0 else { return nil }
    var fixed = draft
    fixed.steps = steps
    fixed.totalTimeS = draft.totalTimeS.map { $0 + delay }
    return (fixed, "Later steps start \(delay) s later so there is time to pour.")
  }

  /// With no AI to tune the batch: what a much bigger or smaller pour-over needs from the
  /// grind, because the bed is deeper or shallower. Nil when the batch is near the recipe's.
  static func batchGrindHint(recipeDoseG: Double, doseG: Double, isPourOver: Bool) -> String? {
    guard isPourOver, recipeDoseG > 0 else { return nil }
    let factor = doseG / recipeDoseG
    if factor >= 1.4 { return "A batch this much bigger drains slower: grind a little coarser." }
    if factor <= 0.7 { return "A batch this much smaller drains faster: grind a little finer." }
    return nil
  }
}
