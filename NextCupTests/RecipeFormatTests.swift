import Foundation
import NextCupKit
import Testing

@testable import NextCup

@Suite("RecipeFormat")
struct RecipeFormatTests {
  let grams = UnitPreferences()
  let imperial = UnitPreferences(weight: .ounces, temperature: .fahrenheit)

  @Test func clockPadsSeconds() {
    #expect(RecipeFormat.clock(0) == "0:00")
    #expect(RecipeFormat.clock(65) == "1:05")
    #expect(RecipeFormat.clock(185) == "3:05")
    #expect(RecipeFormat.clock(-4) == "0:00")
  }

  @Test func spokenTimeUsesWords() {
    #expect(RecipeFormat.spokenTime(45) == "45 seconds")
    #expect(RecipeFormat.spokenTime(60) == "1 minute")
    #expect(RecipeFormat.spokenTime(120) == "2 minutes")
    #expect(RecipeFormat.spokenTime(85) == "1 min 25 seconds")
  }

  @Test func weightFollowsUnits() {
    #expect(RecipeFormat.weight(250, grams) == "250 g")
    #expect(RecipeFormat.weight(15.5, grams) == "15.5 g")
    #expect(RecipeFormat.weight(28.349523125, imperial) == "1.00 oz")
    #expect(RecipeFormat.temperature(94, grams) == "94°C")
    #expect(RecipeFormat.temperature(100, imperial) == "212°F")
  }

  @Test func stepIsSpokenAsKindTimeTarget() {
    let spoken = RecipeFormat.spokenStep(
      kind: .pour, startOffsetS: 85, targetG: 250, units: grams)
    #expect(spoken == "Pour, at 1 min 25 seconds, target 250 grams")
    let noTarget = RecipeFormat.spokenStep(
      kind: .drawdown, startOffsetS: 125, targetG: nil, units: grams)
    #expect(noTarget == "Drawdown, at 2 min 5 seconds")
  }

  @Test func everyStepKindAndStyleHasATitle() {
    for kind in StepKind.allCases { #expect(!RecipeFormat.title(kind).isEmpty) }
    for style in BrewStyle.allCases { #expect(!RecipeFormat.title(style).isEmpty) }
  }

  @Test func recipeStepsSortByOrderAndScaleEveryTarget() throws {
    let recipe = Recipe(name: "Test", doseG: 15, waterG: 250)
    let late = RecipeStep(order: 1, kind: .pour, startOffsetS: 45)
    late.targetCumulativeWaterG = 250
    let early = RecipeStep(order: 0, kind: .bloom, startOffsetS: 0)
    early.targetCumulativeWaterG = 45
    recipe.steps = [late, early]

    #expect(recipe.orderedSteps.map(\.kind) == [.bloom, .pour])

    let scaled = try RecipeScaler.scale(recipe.scalable, toDose: 30)
    #expect(scaled.recipe.waterG == 500)
    #expect(scaled.recipe.steps.map(\.targetCumulativeWaterG) == [90, 500])
    #expect(scaled.recipe.steps.map(\.startOffsetS) == [0, 45])
  }
}
