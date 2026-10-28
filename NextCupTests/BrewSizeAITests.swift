import Foundation
import NextCupKit
import Testing

@testable import NextCup

@MainActor
@Suite("Brew size AI")
struct BrewSizeAITests {
  @Test func anAnswerInsideBrewingBoundsIsKept() {
    let tuning = BrewSizeAI.parse(
      ["tempC": 93.6, "totalTimeS": 240, "grind": "coarser", "note": " Bigger bed. "],
      source: "OpenAI")
    #expect(
      tuning
        == .init(
          tempC: 94, totalTimeS: 240, grind: "coarser", note: "Bigger bed.", source: "OpenAI"))
  }

  @Test func anAnswerOutsideThemIsDropped() {
    #expect(
      BrewSizeAI.parse(["tempC": 140, "totalTimeS": 240, "grind": "same"], source: "x") == nil)
    #expect(BrewSizeAI.parse(["tempC": 94, "totalTimeS": 5, "grind": "same"], source: "x") == nil)
    #expect(BrewSizeAI.parse(["tempC": 94, "totalTimeS": 240], source: "x") == nil)
  }

  @Test func thePayloadCarriesOnlyTheRecipeNumbers() {
    let payload = BrewSizeAI.payload(
      recipe: "Steep then release", method: "Switchable immersion dripper", recipeDoseG: 18,
      doseG: 36.9, waterG: 553, yieldG: 473, tempC: 95, totalTimeS: 210)
    #expect(payload.userText.contains("New dose: 36.9 g, water: 553 g"))
    #expect(payload.userText.contains("total time: 210 s"))
    #expect(payload.imageJPEG == nil)
  }
}
