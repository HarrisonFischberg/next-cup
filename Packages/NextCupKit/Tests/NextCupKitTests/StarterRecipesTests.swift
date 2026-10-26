import Testing

@testable import NextCupKit

@Suite("Starter recipes")
struct StarterRecipesTests {
  private func recipe(_ style: StarterStyle, _ roast: StarterRoast?, _ process: String? = nil)
    -> StarterRecipe
  {
    StarterRecipes.recipe(style: style, roast: roast, process: process)
  }

  @Test func oneRecipePerStyle() {
    let all = StarterRecipes.recipes(roast: .light, process: nil)
    #expect(all.map(\.style) == StarterStyle.allCases)
  }

  @Test func lightRoastsGetHotterWaterAndLongerContact() throws {
    for style in [StarterStyle.pourOver, .immersion, .espresso, .cold] {
      let light = recipe(style, .light)
      let dark = recipe(style, .dark)
      #expect(light.totalTimeS > dark.totalTimeS)
      if style != .cold {
        #expect(try #require(light.tempC) > #require(dark.tempC))
      }
    }
  }

  @Test func roastsInOneBandShareNumbers() {
    func numbers(_ style: StarterStyle, _ roast: StarterRoast) -> StarterRecipe {
      var item = recipe(style, roast)
      item.note = ""
      return item
    }
    #expect(numbers(.pourOver, .ultraLight) == numbers(.pourOver, .light))
    #expect(numbers(.espresso, .mediumLight) == numbers(.espresso, .medium))
    #expect(numbers(.immersion, .mediumDark) == numbers(.immersion, .dark))
  }

  @Test func missingRoastAssumesMediumAndSaysSo() {
    let none = recipe(.pourOver, nil)
    #expect(none.steps == recipe(.pourOver, .medium).steps)
    #expect(none.note.contains("medium roast is assumed"))
  }

  @Test func fermentedProcessStartsOneDegreeCooler() throws {
    let washed = try #require(recipe(.pourOver, .light, "washed").tempC)
    let natural = try #require(recipe(.pourOver, .light, "Natural").tempC)
    #expect(natural == washed - 1)
    #expect(recipe(.cold, .light, "natural").tempC == nil)
  }

  @Test func espressoYieldFollowsRoast() {
    #expect(recipe(.espresso, .light).waterG == 45)
    #expect(recipe(.espresso, .medium).waterG == 36)
    #expect(recipe(.espresso, .dark).waterG == 32)
  }

  @Test func everyRecipeIsTimeableInOrder() throws {
    for roast in StarterRoast.allCases + [nil] {
      for item in StarterRecipes.recipes(roast: roast, process: "natural") {
        let offsets = item.steps.map(\.startOffsetS)
        #expect(offsets == offsets.sorted())
        #expect(try #require(offsets.last) < item.totalTimeS)
        let targets = item.steps.compactMap(\.targetCumulativeWaterG)
        #expect(targets == targets.sorted())
        #expect(try #require(targets.last) == item.waterG)
        #expect(item.doseG > 0)
      }
    }
  }
}
