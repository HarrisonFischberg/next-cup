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

  @Test func overfullAeroPressIsScaledAtTheSameRatio() throws {
    let aeropress = try #require(BrewerFit.current("aeropress", defaults: scratchDefaults()))
    var draft = RecipeDraft()
    draft.name = "Big AeroPress"
    draft.doseG = 20
    draft.waterG = 300
    draft.steps = [
      RecipeStepDraft(
        kind: .pour, startOffsetS: 0, targetCumulativeWaterG: 300,
        instruction: "Pour 300 g over 20 g of coffee."),
      RecipeStepDraft(kind: .press, startOffsetS: 90),
    ]
    let (fixed, note) = try #require(aeropress.fitted(draft))
    #expect(aeropress.overfills(fixed).isEmpty)
    #expect(fixed.waterG == 240 && fixed.doseG == 16)
    #expect(fixed.steps[0].instruction == "Pour 240 g over 16 g of coffee.")
    #expect(note.contains("240 g"))
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
