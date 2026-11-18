import Foundation
import NextCupKit
import Testing

@testable import NextCup

@MainActor
@Suite("Brewer capacity")
struct BrewerCapacityTests {
  private let switch03 = BrewerFit(
    kind: .switchable, size: BrewerCapacity.sizes(for: "switchable-dripper")[1])

  /// The recipe Harold got: 307 + 307 g into a Switch 03 with the valve closed.
  private func overfilledSwitch() -> RecipeDraft {
    var draft = RecipeDraft()
    draft.name = "Next Cup"
    draft.doseG = 41
    draft.waterG = 614
    draft.tempC = 94
    draft.totalTimeS = 240
    draft.steps = [
      RecipeStepDraft(kind: .closeValve, startOffsetS: 0, instruction: "Close the valve."),
      RecipeStepDraft(
        kind: .pour, startOffsetS: 0, targetCumulativeWaterG: 307, instruction: "Pour 307 g."),
      RecipeStepDraft(
        kind: .pour, startOffsetS: 30, targetCumulativeWaterG: 614, instruction: "Pour 307 g."),
      RecipeStepDraft(kind: .stir, startOffsetS: 60, instruction: "Stir gently."),
      RecipeStepDraft(kind: .openValve, startOffsetS: 150, instruction: "Open the valve."),
      RecipeStepDraft(kind: .drawdown, startOffsetS: 180, instruction: "Let it drain."),
    ]
    return draft
  }

  private func scratchDefaults() -> UserDefaults {
    let name = "brewer-capacity-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
  }

  @Test func tableHasSaneSizesAndDefaults() {
    #expect(switch03.size.name == "Hario Switch 03")
    #expect(switch03.size.heldG == 410 && switch03.size.pourG == 480)
    let switch02 = BrewerCapacity.sizes(for: "switchable-dripper")[0]
    #expect(switch02.heldG == 240 && switch02.pourG == 300)
    for (key, method) in BrewerCapacity.methods {
      #expect(BrewerCapacity.defaultSize(for: key) != nil, "\(key) has a default")
      #expect(Set(method.sizes.map(\.id)).count == method.sizes.count, "\(key) ids unique")
      for size in method.sizes {
        #expect(size.heldG > 0 && size.pourG >= size.heldG, "\(size.id)")
      }
    }
    #expect(BrewerCapacity.sizes(for: "espresso").isEmpty)
    #expect(BrewerCapacity.sizes(for: nil).isEmpty)
    // Every method key in the table is a real built-in method.
    let url = Bundle.main.url(forResource: "methods", withExtension: "json")
    if let url, let data = try? Data(contentsOf: url),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let methods = json["methods"] as? [[String: Any]]
    {
      let keys = Set(methods.compactMap { $0["key"] as? String })
      #expect(Set(BrewerCapacity.methods.keys).isSubset(of: keys))
    }
  }

  @Test func sizeIsAskedOnceThenStored() {
    let defaults = scratchDefaults()
    #expect(BrewerCapacity.needsAsking("switchable-dripper", defaults: defaults))
    #expect(!BrewerCapacity.needsAsking("espresso", defaults: defaults))
    let fit = BrewerFit.current("switchable-dripper", defaults: defaults)
    #expect(fit?.size.id == "switch-03" && fit?.assumed == true)
    BrewerCapacity.choose(
      BrewerCapacity.sizes(for: "switchable-dripper")[0], for: "switchable-dripper",
      defaults: defaults)
    #expect(!BrewerCapacity.needsAsking("switchable-dripper", defaults: defaults))
    let picked = BrewerFit.current("switchable-dripper", defaults: defaults)
    #expect(picked?.size.id == "switch-02" && picked?.assumed == false)
  }

  @Test func switch03ClosedWith307And307Overfills() {
    let overfills = switch03.overfills(overfilledSwitch())
    #expect(overfills.count == 1)
    #expect(overfills.first?.heldG == 614 && overfills.first?.limitG == 410)
    #expect(overfills.first?.whileHeld == true)
    #expect(switch03.problem(overfilledSwitch())?.contains("410") == true)
  }

  @Test func switch03ClosedWith307And307IsFixed() throws {
    let original = overfilledSwitch()
    let (fixed, note) = try #require(switch03.fitted(original))
    #expect(switch03.overfills(fixed).isEmpty)
    #expect(RecipeEditorService.validate(fixed) == nil)
    #expect(RecipeReviewAI.pourAddsUp(fixed))
    let sorted = RecipeEditorService.sorted(fixed.steps)
    #expect(sorted.compactMap(\.targetCumulativeWaterG).max() == 614)
    // 410 g held closed, the other 204 g poured after the valve opens.
    #expect(sorted.compactMap(\.targetCumulativeWaterG) == [307, 410, 614])
    let open = try #require(sorted.firstIndex { $0.kind == .openValve })
    #expect(sorted[(open + 1)...].contains { $0.targetCumulativeWaterG == 614 })
    #expect(note.contains("Hario Switch 03"))
    #expect(sorted.contains { $0.instruction.contains("103 g") })
  }

  @Test func switchThatNeverOpensGetsAValve() throws {
    var draft = overfilledSwitch()
    draft.steps.removeAll { $0.kind == .openValve }
    let (fixed, _) = try #require(switch03.fitted(draft))
    #expect(switch03.overfills(fixed).isEmpty)
    #expect(fixed.steps.contains { $0.kind == .openValve })
    #expect(fixed.steps.compactMap(\.targetCumulativeWaterG).max() == 614)
  }

  /// Harold's 18 oz Switch brew of 2026-11-18: 82, 409, then 614 g closed came out as a
  /// 1 g pour, and the 204 g after the valve opened had no time before the drawdown.
  @Test func splitNeverLeavesADribble() throws {
    var draft = overfilledSwitch()
    draft.steps = [
      RecipeStepDraft(kind: .closeValve, startOffsetS: 0),
      RecipeStepDraft(kind: .bloom, startOffsetS: 0, targetCumulativeWaterG: 82),
      RecipeStepDraft(kind: .pour, startOffsetS: 30, targetCumulativeWaterG: 409),
      RecipeStepDraft(kind: .pour, startOffsetS: 60, targetCumulativeWaterG: 614),
      RecipeStepDraft(kind: .wait, startOffsetS: 75),
      RecipeStepDraft(kind: .openValve, startOffsetS: 150),
      RecipeStepDraft(kind: .drawdown, startOffsetS: 150),
    ]
    draft.totalTimeS = 210
    let (fixed, _) = try #require(switch03.fitted(draft))
    #expect(switch03.overfills(fixed).isEmpty)
    #expect(RecipeEditorService.validate(fixed) == nil)
    let sorted = RecipeEditorService.sorted(fixed.steps)
    #expect(sorted.compactMap(\.targetCumulativeWaterG) == [82, 409, 614])
    #expect(
      sorted.map(\.kind) == [.closeValve, .bloom, .pour, .wait, .openValve, .pour, .drawdown])
    // The drawdown and the end wait for the pour that now comes after the valve.
    #expect(sorted.last?.startOffsetS == 170 && fixed.totalTimeS == 230)
  }

  /// 10 g too much does not become a 10 g pour: the last closed pour gives some up.
  @Test func aSmallOverflowTakesWaterFromThePourBeforeIt() throws {
    var draft = overfilledSwitch()
    draft.waterG = 420
    draft.steps[1].targetCumulativeWaterG = 200
    draft.steps[2].targetCumulativeWaterG = 420
    let (fixed, _) = try #require(switch03.fitted(draft))
    #expect(switch03.overfills(fixed).isEmpty)
    let targets = RecipeEditorService.sorted(fixed.steps).compactMap(\.targetCumulativeWaterG)
    #expect(targets == [200, 400, 420])
  }

  @Test func hybridWithinLimitsFits() {
    var draft = overfilledSwitch()
    draft.steps[2].startOffsetS = 160  // second pour after the valve opens
    #expect(switch03.overfills(draft).isEmpty)
    #expect(switch03.fitted(draft) == nil)
  }

  @Test func bigConePourIsSplitKeepingTheWater() throws {
    let cone = try #require(BrewerFit.current("cone-dripper", defaults: scratchDefaults()))
    var draft = RecipeDraft()
    draft.name = "One pour"
    draft.doseG = 30
    draft.waterG = 500
    draft.totalTimeS = 210
    draft.steps = [
      RecipeStepDraft(kind: .bloom, startOffsetS: 0, targetCumulativeWaterG: 60),
      RecipeStepDraft(kind: .pour, startOffsetS: 45, targetCumulativeWaterG: 500),
      RecipeStepDraft(kind: .drawdown, startOffsetS: 150),
    ]
    #expect(cone.overfills(draft).count == 1)
    let (fixed, _) = try #require(cone.fitted(draft))
    #expect(cone.overfills(fixed).isEmpty)
    #expect(RecipeEditorService.validate(fixed) == nil)
    let targets = RecipeEditorService.sorted(fixed.steps).compactMap(\.targetCumulativeWaterG)
    #expect(targets == [60, 280, 500])
    #expect(fixed.steps.allSatisfy { $0.startOffsetS <= 150 })
  }

  private func bigAeroPress(waterG: Double) -> RecipeDraft {
    var draft = RecipeDraft()
    draft.name = "Big AeroPress"
    draft.doseG = 20
    draft.waterG = waterG
    draft.steps = [
      RecipeStepDraft(
        kind: .pour, startOffsetS: 0, targetCumulativeWaterG: waterG,
        instruction: "Pour \(Int(waterG)) g over 20 g of coffee."),
      RecipeStepDraft(kind: .press, startOffsetS: 90),
    ]
    return draft
  }

  @Test func aLittleTooMuchForAnAeroPressGoesToTheCup() throws {
    let aeropress = try #require(BrewerFit.current("aeropress", defaults: scratchDefaults()))
    let (fixed, note) = try #require(aeropress.fitted(bigAeroPress(waterG: 300)))
    #expect(aeropress.overfills(fixed).isEmpty)
    #expect(RecipeEditorService.validate(fixed) == nil)
    #expect(fixed.waterG == 300 && fixed.doseG == 20)
    #expect(fixed.steps[0].targetCumulativeWaterG == 240)
    #expect(fixed.steps[0].instruction == "Pour to 240 g.")
    let last = try #require(fixed.steps.last)
    #expect(last.kind == .bypass && last.targetCumulativeWaterG == 300)
    #expect(last.instruction.contains("60 g"))
    #expect(note.contains("60 g"))
  }

  @Test func farTooMuchForAnAeroPressIsScaledAtTheSameRatio() throws {
    let aeropress = try #require(BrewerFit.current("aeropress", defaults: scratchDefaults()))
    let (fixed, note) = try #require(aeropress.fitted(bigAeroPress(waterG: 500)))
    #expect(aeropress.overfills(fixed).isEmpty)
    #expect(fixed.waterG == 240 && fixed.doseG == 9.6)
    #expect(!fixed.steps.contains { $0.kind == .bypass })
    #expect(note.contains("240 g"))
  }

  /// A built-in recipe is never changed for someone who has not said which size they own.
  @Test func builtInRecipesFitTheAssumedSizes() throws {
    let defaults = scratchDefaults()
    for entry in try BuiltInContent().recipes {
      guard let fit = BrewerFit.current(entry.methodKey, defaults: defaults) else { continue }
      var draft = RecipeDraft()
      draft.doseG = entry.doseG
      draft.waterG = entry.waterG
      draft.steps = entry.steps.map {
        RecipeStepDraft(
          kind: $0.kind, startOffsetS: $0.startOffsetS,
          targetCumulativeWaterG: $0.targetCumulativeWaterG, instruction: $0.instruction)
      }
      #expect(fit.overfills(draft).isEmpty, "\(entry.key) on \(fit.size.name)")
    }
  }

  /// The engine has nothing to say about a built-in recipe at its own size.
  @Test func engineLeavesBuiltInRecipesAlone() throws {
    let defaults = scratchDefaults()
    for entry in try BuiltInContent().recipes {
      var draft = RecipeDraft()
      draft.doseG = entry.doseG
      draft.waterG = entry.waterG
      draft.totalTimeS = entry.totalTimeS
      draft.steps = entry.steps.map {
        RecipeStepDraft(
          kind: $0.kind, startOffsetS: $0.startOffsetS,
          targetCumulativeWaterG: $0.targetCumulativeWaterG, instruction: $0.instruction)
      }
      let plan = BrewEngine.plan(draft, methodKey: entry.methodKey, defaults: defaults)
      #expect(plan.notes.isEmpty, "\(entry.key): \(plan.notes)")
      #expect(plan.draft == draft, "\(entry.key)")
    }
  }

  @Test func engineFoldsAPourTooSmallToPour() throws {
    var draft = RecipeDraft()
    draft.doseG = 30
    draft.waterG = 500
    draft.totalTimeS = 210
    draft.steps = [
      RecipeStepDraft(kind: .bloom, startOffsetS: 0, targetCumulativeWaterG: 60),
      RecipeStepDraft(
        kind: .pour, startOffsetS: 45, targetCumulativeWaterG: 250, instruction: "Pour 190 g."),
      RecipeStepDraft(kind: .pour, startOffsetS: 75, targetCumulativeWaterG: 253),
      RecipeStepDraft(kind: .pour, startOffsetS: 105, targetCumulativeWaterG: 500),
      RecipeStepDraft(kind: .drawdown, startOffsetS: 150),
    ]
    let plan = BrewEngine.plan(draft, methodKey: "cone-dripper", defaults: scratchDefaults())
    #expect(plan.draft.steps.compactMap(\.targetCumulativeWaterG) == [60, 253, 500])
    #expect(plan.draft.steps[1].instruction == "Pour to 253 g.")
    #expect(plan.notes.count == 1)
    #expect(RecipeEditorService.validate(named(plan.draft)) == nil)
  }

  @Test func engineGivesAPourTimeBeforeTheNextStep() throws {
    var draft = RecipeDraft()
    draft.doseG = 20
    draft.waterG = 300
    draft.totalTimeS = 180
    draft.steps = [
      RecipeStepDraft(kind: .pour, startOffsetS: 0, targetCumulativeWaterG: 300),
      RecipeStepDraft(kind: .stir, startOffsetS: 0),
      RecipeStepDraft(kind: .press, startOffsetS: 120),
    ]
    let plan = BrewEngine.plan(draft, methodKey: nil)
    #expect(plan.draft.steps.map(\.startOffsetS) == [0, 5, 125])
    #expect(plan.draft.totalTimeS == 185)
  }

  @Test func bigAndSmallPourOverBatchesGetAGrindHint() {
    #expect(BrewEngine.batchGrindHint(recipeDoseG: 15, doseG: 30, isPourOver: true) != nil)
    #expect(BrewEngine.batchGrindHint(recipeDoseG: 30, doseG: 15, isPourOver: true) != nil)
    #expect(BrewEngine.batchGrindHint(recipeDoseG: 15, doseG: 17, isPourOver: true) == nil)
    #expect(BrewEngine.batchGrindHint(recipeDoseG: 15, doseG: 30, isPourOver: false) == nil)
  }

  private func named(_ draft: RecipeDraft) -> RecipeDraft {
    var draft = draft
    draft.name = "Test"
    return draft
  }

  /// Harold's brew of 2026-11-17: a built-in Switch steep turned up to 600 g of water.
  @Test func timerSplitsAScaledUpSwitchSteep() throws {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: BrewerCapacity.storageKey("switchable-dripper"))
    let method = BrewMethod(name: "Switch", style: .immersion)
    method.builtInKey = "switchable-dripper"
    let recipe = Recipe(name: "Steep then release", doseG: 18, waterG: 270)
    recipe.method = method
    recipe.totalTimeS = 210
    let kinds: [(StepKind, Int, Double?)] = [
      (.closeValve, 0, nil), (.pour, 0, 270), (.stir, 30, nil), (.openValve, 120, nil),
      (.drawdown, 125, nil),
    ]
    recipe.steps = kinds.enumerated().map { index, entry in
      let step = RecipeStep(order: index, kind: entry.0, startOffsetS: entry.1)
      step.targetCumulativeWaterG = entry.2
      return step
    }
    let setup = try TimerPlanBuilder.setup(for: recipe, doseG: 40)
    #expect(setup.scaled.waterG == 600)
    #expect(setup.plan.steps.compactMap(\.targetCumulativeWaterG) == [410, 600])
    #expect(setup.stepKinds == ["closeValve", "pour", "stir", "openValve", "pour", "drawdown"])
    // Reopened from the Live Activity at the same dose, it is the same plan.
    #expect(try TimerPlanBuilder.setup(for: recipe, doseG: 40).plan == setup.plan)
  }

  @Test func timerMakesAMokaPotBrewSmallerAndReopensTheSame() throws {
    UserDefaults.standard.removeObject(forKey: BrewerCapacity.storageKey("moka-pot"))
    let method = BrewMethod(name: "Moka", style: .immersion)
    method.builtInKey = "moka-pot"
    let recipe = Recipe(name: "Moka", doseG: 15, waterG: 150)
    recipe.method = method
    let fill = RecipeStep(order: 0, kind: .pour, startOffsetS: 0)
    fill.targetCumulativeWaterG = 150
    recipe.steps = [fill, RecipeStep(order: 1, kind: .heat, startOffsetS: 20)]
    let setup = try TimerPlanBuilder.setup(for: recipe, doseG: 30)
    #expect(setup.scaled.doseG <= 19 && setup.scaled.doseG > 18.5)
    #expect((setup.plan.steps[0].targetCumulativeWaterG ?? 999) <= 192)
    let reopened = try TimerPlanBuilder.setup(for: recipe, doseG: setup.scaled.doseG)
    #expect(reopened.plan == setup.plan)
  }

  @Test func bypassWaterIsNotHeld() throws {
    let aeropress = try #require(BrewerFit.current("aeropress", defaults: scratchDefaults()))
    var draft = RecipeDraft()
    draft.doseG = 18
    draft.waterG = 400
    draft.steps = [
      RecipeStepDraft(kind: .pour, startOffsetS: 0, targetCumulativeWaterG: 200),
      RecipeStepDraft(kind: .press, startOffsetS: 90),
      RecipeStepDraft(kind: .bypass, startOffsetS: 120, targetCumulativeWaterG: 400),
    ]
    #expect(aeropress.overfills(draft).isEmpty)
  }

  @Test func promptStatesTheLimitsAndTheRule() {
    let line = switch03.promptLine
    #expect(line.contains("Hario Switch 03"))
    #expect(line.contains("410 g") && line.contains("480 g"))
    #expect(line.contains("valve is closed"))
    let payload = RecipeReviewAI.payload(
      overfilledSwitch(), methodName: "Switchable immersion dripper", note: "", brewer: switch03)
    #expect(payload.userText.contains(line))
    let create = RecipeReviewAI.createPayload(
      methodName: "Switchable immersion dripper", style: "Immersion", note: "18 oz",
      brewer: switch03)
    #expect(create.userText.contains(line))
  }

  @Test func overfillIsAskedAgainOnceThenSplit() async throws {
    let base = overfilledSwitch()
    let review = RecipeReviewAI.Review(
      summary: "Steep it all.", changes: [], draft: base, source: "Test")
    let payload = RecipeReviewAI.payload(base, methodName: "Switch", note: "", brewer: switch03)
    var asked: [String] = []
    // The second answer overfills too, so the first one's pours are split.
    let fixed = try await RecipeReviewAI.fit(
      review, brewer: switch03, payload: payload, base: base, mode: .improve,
      send: { request in
        asked.append(request.userText)
        return (["steps": []], "Test")
      })
    #expect(asked.count == 1)
    #expect(asked.first?.contains("overfilled the Hario Switch 03") == true)
    #expect(switch03.overfills(fixed.draft).isEmpty)
    #expect(fixed.summary.hasPrefix("Steep it all. Adjusted to fit your brewer"))
  }

  /// A hybrid: an open pour drains, then the valve closes for a steep that fills the brewer.
  @Test func waterPouredBeforeTheValveClosesHasDrained() {
    var draft = overfilledSwitch()
    let full = 160 + switch03.size.heldG
    draft.steps = [
      RecipeStepDraft(kind: .pour, startOffsetS: 0, targetCumulativeWaterG: 160),
      RecipeStepDraft(kind: .closeValve, startOffsetS: 45),
      RecipeStepDraft(kind: .pour, startOffsetS: 45, targetCumulativeWaterG: full),
      RecipeStepDraft(kind: .openValve, startOffsetS: 150),
    ]
    #expect(switch03.overfills(draft).isEmpty)
  }

  @Test func aFittingRetryIsUsed() async throws {
    let base = overfilledSwitch()
    let review = RecipeReviewAI.Review(summary: "", changes: [], draft: base, source: "Test")
    let fixed = try await RecipeReviewAI.fit(
      review, brewer: switch03,
      payload: RecipeReviewAI.payload(base, methodName: "Switch", note: ""), base: base,
      mode: .improve,
      send: { _ in
        (
          [
            "summary": "Hybrid.",
            "steps": [
              ["kind": "closeValve", "atS": 0, "waterG": 0, "instruction": "Close the valve."],
              ["kind": "pour", "atS": 0, "waterG": 400, "instruction": "Pour 400 g."],
              ["kind": "openValve", "atS": 120, "waterG": 0, "instruction": "Open the valve."],
              ["kind": "pour", "atS": 130, "waterG": 614, "instruction": "Pour the rest."],
            ],
          ], "Test"
        )
      })
    #expect(fixed.summary == "Hybrid.")
    #expect(switch03.overfills(fixed.draft).isEmpty)
  }
}
