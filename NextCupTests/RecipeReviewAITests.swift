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
      "tempC": 95, "totalTimeS": 270, "steps": steps,
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
    #expect(review.steps.map(\.targetCumulativeWaterG) == [nil, 400, nil, 615])
    #expect(review.steps[1].instruction == "Pour to 400 g.")
    #expect(review.tempC == 95 && review.totalTimeS == 270)
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
    #expect(review.steps.map(\.targetCumulativeWaterG) == [615, nil])
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
    #expect(review.tempC == 94 && review.totalTimeS == 260)
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
}
