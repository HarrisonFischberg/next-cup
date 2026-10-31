import Foundation
import NextCupKit
import Testing

@testable import NextCup

@MainActor
@Suite("Recipe review AI")
struct RecipeReviewAITests {
  /// Steep then release at 18 oz: all 615 g in one pour, more than a 400 g cone holds.
  private func base() -> RecipeDraft {
    var draft = RecipeDraft()
    draft.name = "Steep then release (18 oz)"
    draft.doseG = 41
    draft.waterG = 615
    draft.tempC = 94
    draft.totalTimeS = 260
    draft.steps = [
      RecipeStepDraft(kind: .closeValve, startOffsetS: 0, instruction: "Close the valve."),
      RecipeStepDraft(
        kind: .pour, startOffsetS: 0, targetCumulativeWaterG: 615, instruction: "Pour it all."),
      RecipeStepDraft(kind: .openValve, startOffsetS: 150, instruction: "Open the valve."),
    ]
    return draft
  }

  private func answer(steps: [[String: Any]]) -> [String: Any] {
    [
      "summary": "Split the pour so the cone never overflows.",
      "changes": [["what": "Two pours", "why": "The cone holds about 400 g."]],
      "name": "", "doseG": 0, "waterG": 0, "tempC": 95, "totalTimeS": 270, "steps": steps,
      "grind": "",
    ]
  }

  @Test func aSplitPourThatAddsUpIsKept() throws {
    let review = try #require(
      RecipeReviewAI.parse(
        answer(steps: [
          ["kind": "closeValve", "atS": 0, "waterG": 0, "instruction": "Close the valve."],
          ["kind": "pour", "atS": 0, "waterG": 400, "instruction": " Pour to 400 g. "],
          ["kind": "openValve", "atS": 120, "waterG": 0, "instruction": "Open to drain."],
          ["kind": "pour", "atS": 150, "waterG": 615, "instruction": "Pour the rest."],
        ]), base: base(), source: "Anthropic"))
    #expect(review.draft.steps.map(\.targetCumulativeWaterG) == [nil, 400, nil, 615])
    #expect(review.draft.steps[1].instruction == "Pour to 400 g.")
    #expect(review.draft.tempC == 95 && review.draft.totalTimeS == 270)
    #expect(review.changes == [.init(what: "Two pours", why: "The cone holds about 400 g.")])
    #expect(review.source == "Anthropic")
  }

  @Test func waterOnAStepThatPoursNothingIsDropped() throws {
    let review = try #require(
      RecipeReviewAI.parse(
        answer(steps: [
          ["kind": "pour", "atS": 0, "waterG": 615, "instruction": ""],
          ["kind": "wait", "atS": 30, "waterG": 615, "instruction": ""],
        ]), base: base(), source: "x"))
    #expect(review.draft.steps.map(\.targetCumulativeWaterG) == [615, nil])
  }

  @Test func stepsThatDoNotAddUpAreRejected() {
    // More water than the recipe uses.
    #expect(
      RecipeReviewAI.parse(
        answer(steps: [["kind": "pour", "atS": 0, "waterG": 700, "instruction": ""]]),
        base: base(), source: "x") == nil)
    // Running totals that go backwards.
    #expect(
      RecipeReviewAI.parse(
        answer(steps: [
          ["kind": "pour", "atS": 0, "waterG": 400, "instruction": ""],
          ["kind": "pour", "atS": 60, "waterG": 300, "instruction": ""],
        ]), base: base(), source: "x") == nil)
    // An unknown step kind, and no steps at all.
    #expect(
      RecipeReviewAI.parse(
        answer(steps: [["kind": "dance", "atS": 0, "waterG": 0, "instruction": ""]]),
        base: base(), source: "x") == nil)
    #expect(RecipeReviewAI.parse(answer(steps: []), base: base(), source: "x") == nil)
  }

  @Test func anOutOfRangeTemperatureKeepsTheRecipes() throws {
    var raw = answer(steps: [["kind": "pour", "atS": 0, "waterG": 615, "instruction": ""]])
    raw["tempC"] = 0
    raw["totalTimeS"] = 0
    let review = try #require(RecipeReviewAI.parse(raw, base: base(), source: "x"))
    #expect(review.draft.tempC == 94 && review.draft.totalTimeS == 260)
  }

  @Test func thePayloadCarriesTheRecipeStepsAndNoteOnly() {
    let payload = RecipeReviewAI.payload(
      base(), methodName: "Switchable dripper", note: " My cone only holds about 400 g ")
    #expect(payload.userText.contains("Recipe: Steep then release (18 oz) on a Switchable dripper"))
    #expect(payload.userText.contains("Dose: 41 g, total water: 615 g"))
    #expect(payload.userText.contains("Their note: My cone only holds about 400 g"))
    #expect(payload.userText.contains("2. at 0 s, pour, to 615 g: Pour it all."))
    #expect(payload.imageJPEG == nil)
    #expect(payload.schema.validates(answer(steps: [])))
  }

  @Test func pourTargetsThatStopShortOfTheWaterAreRejected() {
    // What the on-device model answered for the 400 g cone: a 200 g bloom and nothing more.
    #expect(
      RecipeReviewAI.parse(
        answer(steps: [
          ["kind": "closeValve", "atS": 0, "waterG": 0, "instruction": "closeValve"],
          ["kind": "bloom", "atS": 0, "waterG": 200, "instruction": "bloom"],
          ["kind": "openValve", "atS": 120, "waterG": 0, "instruction": "openValve"],
        ]), base: base(), source: "x") == nil)
  }

  @Test func anInstructionThatOnlyNamesTheStepIsCleared() throws {
    let review = try #require(
      RecipeReviewAI.parse(
        answer(steps: [
          ["kind": "closeValve", "atS": 0, "waterG": 0, "instruction": "closeValve"],
          ["kind": "pour", "atS": 0, "waterG": 615, "instruction": "Pour"],
        ]), base: base(), source: "x"))
    #expect(review.draft.steps.map(\.instruction) == ["", ""])
  }

  @Test func aNoteThatAsksForOtherAmountsCanChangeThem() throws {
    // "600 g total, my dripper holds 400 g": a hybrid at 600 g and the dose kept to ratio.
    var raw = answer(steps: [
      ["kind": "closeValve", "atS": 0, "waterG": 0, "instruction": "Close the valve."],
      ["kind": "pour", "atS": 0, "waterG": 300, "instruction": "Pour 300 g."],
      ["kind": "openValve", "atS": 120, "waterG": 0, "instruction": "Open to drain."],
      ["kind": "pour", "atS": 150, "waterG": 600, "instruction": "Pulse-pour to 600 g."],
      ["kind": "drawdown", "atS": 200, "waterG": 0, "instruction": "Let it drain."],
    ])
    raw["doseG"] = 40
    raw["waterG"] = 600
    let review = try #require(RecipeReviewAI.parse(raw, base: base(), source: "OpenAI"))
    #expect(review.draft.doseG == 40 && review.draft.waterG == 600)
    #expect(review.draft.name == "Steep then release (18 oz)")
  }

  @Test func creatingTakesTheAIsNameAndNumbers() throws {
    var base = RecipeDraft()
    base.name = "AeroPress (AI)"
    var raw = answer(steps: [
      ["kind": "pour", "atS": 0, "waterG": 220, "instruction": "Pour 220 g."],
      ["kind": "press", "atS": 90, "waterG": 0, "instruction": "Press gently for 30 s."],
    ])
    raw["name"] = "Sweet inverted press"
    raw["doseG"] = 15
    raw["waterG"] = 220
    let review = try #require(
      RecipeReviewAI.parse(raw, base: base, source: "x", mode: .create))
    #expect(review.draft.name == "Sweet inverted press")
    #expect(review.draft.doseG == 15 && review.draft.waterG == 220)
    // With no dose from the AI, a new recipe has nothing to stand on.
    raw["doseG"] = 0
    #expect(RecipeReviewAI.parse(raw, base: base, source: "x", mode: .create) == nil)
  }

  @Test func theCreatePayloadCarriesOnlyTheBrewerAndTheNote() {
    let payload = RecipeReviewAI.createPayload(
      methodName: "Switchable dripper", style: "Immersion", note: " 600 g, cone holds 400 g ")
    #expect(
      payload.userText
        == "Brewer: Switchable dripper (Immersion)\nWhat they want: 600 g, cone holds 400 g")
    #expect(payload.imageJPEG == nil)
  }

  @Test func theGrinderGoesWithTheGuidesRangeWhenItIsKnown() {
    let known = RecipeReviewAI.createPayload(
      methodName: "Cone dripper", style: "Pour-over", note: "A bright cup",
      grinder: "comandante c40 mk4")
    #expect(
      known.userText.contains(
        "Grinder: comandante c40 mk4 (guide's starting range for this brewer: 15 – 25 clicks)"))
    let typed = RecipeReviewAI.payload(
      base(), methodName: "Switchable dripper", note: "", grinder: " My old Krups ")
    #expect(typed.userText.contains("Grinder: My old Krups\n"))
    #expect(!RecipeReviewAI.payload(base(), methodName: nil, note: "").userText.contains("Grinder"))
  }

  @Test func theGrindIsKeptAndWrittenIntoTheNote() throws {
    var raw = answer(steps: [["kind": "pour", "atS": 0, "waterG": 615, "instruction": ""]])
    raw["grind"] = " 22 clicks "
    let review = try #require(RecipeReviewAI.parse(raw, base: base(), source: "x"))
    #expect(review.grind == "22 clicks")
    let note = RecipeReviewAI.note("Sweet.", grind: review.grind, grinder: "C40")
    #expect(note == "Sweet.\n\nGrind: 22 clicks on C40.")
    // A second suggestion replaces the first grind line instead of stacking.
    #expect(
      RecipeReviewAI.note(note, grind: "20 clicks", grinder: "C40")
        == "Sweet.\n\nGrind: 20 clicks on C40.")
    #expect(RecipeReviewAI.note(nil, grind: "20", grinder: "C40") == "Grind: 20 on C40.")
    // No grinder or no grind leaves the note alone.
    #expect(RecipeReviewAI.note(note, grind: "", grinder: "C40") == note)
    #expect(RecipeReviewAI.note("Sweet.", grind: "20", grinder: nil) == "Sweet.")
  }

  @Test func valveStepsOnlyWorkTheValve() throws {
    // Live answers folded the bloom into the close step, or left the close step out.
    let folded = try #require(
      RecipeReviewAI.parse(
        answer(steps: [
          [
            "kind": "closeValve", "atS": 0, "waterG": 0,
            "instruction": "Close the valve, add 36 g of coffee and pour 72 g of water.",
          ],
          ["kind": "bloom", "atS": 0, "waterG": 72, "instruction": "Pour 72 g to bloom."],
          ["kind": "openValve", "atS": 120, "waterG": 0, "instruction": "Open the valve."],
          ["kind": "pour", "atS": 150, "waterG": 615, "instruction": "Pour the rest."],
        ]), base: base(), source: "x", mode: .create))
    #expect(folded.draft.steps[0].instruction == "Close the valve.")
    #expect(folded.draft.steps[2].instruction == "Open the valve.")

    let missing = try #require(
      RecipeReviewAI.parse(
        answer(steps: [
          ["kind": "bloom", "atS": 0, "waterG": 72, "instruction": "Close the valve and bloom."],
          ["kind": "openValve", "atS": 120, "waterG": 0, "instruction": "Open the valve."],
          ["kind": "pour", "atS": 150, "waterG": 615, "instruction": "Pour the rest."],
        ]), base: base(), source: "x", mode: .create))
    #expect(missing.draft.steps.map(\.kind) == [.closeValve, .bloom, .openValve, .pour])
  }
}
