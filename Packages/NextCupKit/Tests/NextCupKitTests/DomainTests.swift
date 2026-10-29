import Foundation
import Testing

@testable import NextCupKit

@Suite struct BrewMathTests {
  @Test func doseForYieldAllowsForWaterTheGroundsKeep() {
    // 18 g at 1:15 is 270 g of water, less 36 g held in the grounds: 234 g in the cup.
    #expect(abs(BrewMath.dose(forYieldG: 234, ratio: 15)! - 18) < 0.0001)
    #expect(BrewMath.dose(forYieldG: 36, ratio: 2) == 18)
    #expect(BrewMath.dose(forYieldG: 0, ratio: 15) == nil)
    #expect(BrewMath.dose(forYieldG: 200, ratio: nil) == nil)
  }

  @Test func cupIsWhatThePourLeavesAfterTheGroundsDrink() {
    // 18 oz asked of a 1:15 steep: pour about 614 g on 41 g and about 532 g (18 oz) comes out.
    let cup = 18 * 29.5735
    let dose = BrewMath.dose(forYieldG: cup, ratio: 15)!
    #expect(abs(dose * 15 - 614.0) < 1)
    #expect(abs(BrewMath.cupG(waterG: dose * 15, doseG: dose)! - cup) < 0.0001)
    #expect(BrewMath.cupG(waterG: 36, doseG: 18) == 36)
    #expect(BrewMath.cupG(waterG: 0, doseG: 18) == nil)
  }

  @Test func ratioDividesWaterByDose() {
    #expect(BrewMath.ratio(doseG: 15, waterG: 250) == 250.0 / 15.0)
    #expect(BrewMath.ratioLabel(BrewMath.ratio(doseG: 15, waterG: 250)) == "1:16.7")
  }

  @Test func iceCountsTowardWater() {
    #expect(BrewMath.ratio(doseG: 20, waterG: 200, iceG: 120) == 16)
  }

  @Test func missingOrNonPositiveInputsAreNilNotZero() {
    #expect(BrewMath.ratio(doseG: nil, waterG: 250) == nil)
    #expect(BrewMath.ratio(doseG: 15, waterG: nil) == nil)
    #expect(BrewMath.ratio(doseG: 0, waterG: 250) == nil)
    #expect(BrewMath.espressoRatio(doseG: 18, yieldG: nil) == nil)
    #expect(BrewMath.extractionYield(tds: 1.4, beverageG: nil, doseG: 15) == nil)
    #expect(BrewMath.ratioLabel(nil) == nil)
  }

  @Test func espressoRatioUsesYield() {
    #expect(BrewMath.espressoRatio(doseG: 18, yieldG: 36) == 2)
  }

  @Test func extractionYieldIsTDSTimesBeverageOverDose() throws {
    let value = try #require(BrewMath.extractionYield(tds: 1.4, beverageG: 250, doseG: 15))
    #expect(abs(value - 23.3333) < 0.001)
  }
}

@Suite struct RecipeScalerTests {
  private let recipe = ScalableRecipe(
    doseG: 15, waterG: 250,
    steps: [
      ScalableStep(order: 0, startOffsetS: 0, targetCumulativeWaterG: 45),
      ScalableStep(order: 1, startOffsetS: 45, targetCumulativeWaterG: nil),
      ScalableStep(order: 2, startOffsetS: 75, targetCumulativeWaterG: 250),
    ])

  @Test func scalesEveryTargetAndKeepsTiming() throws {
    let scaled = try RecipeScaler.scale(recipe, toDose: 30)
    #expect(scaled.factor == 2)
    #expect(scaled.recipe.waterG == 500)
    #expect(scaled.recipe.steps.map(\.targetCumulativeWaterG) == [90, nil, 500])
    #expect(scaled.recipe.steps.map(\.startOffsetS) == [0, 45, 75])
    #expect(scaled.notes.isEmpty)
  }

  @Test func roundingProducesANote() throws {
    let scaled = try RecipeScaler.scale(recipe, toDose: 16)
    #expect(scaled.recipe.waterG == 267)
    #expect(scaled.recipe.steps[0].targetCumulativeWaterG == 48)
    #expect(scaled.notes.count == 1)
    #expect(scaled.notes[0].contains("rounded"))
  }

  @Test func roundedTargetsStayInOrder() throws {
    let scaled = try RecipeScaler.scale(recipe, toDose: 17.3)
    let targets = scaled.recipe.steps.compactMap(\.targetCumulativeWaterG)
    #expect(targets == targets.sorted())
  }

  @Test func iceScalesAndCountsTowardTotalWater() throws {
    let iced = ScalableRecipe(doseG: 20, waterG: 200, iceG: 120, includesIce: true)
    let scaled = try RecipeScaler.scale(iced, toDose: 10)
    #expect(scaled.recipe.waterG == 100)
    #expect(scaled.recipe.iceG == 60)
    #expect(scaled.recipe.totalWaterG == 160)
    #expect(BrewMath.ratio(doseG: 10, waterG: 100, iceG: 60) == 16)
  }

  @Test func doseRoundsToATenthWithANote() throws {
    let scaled = try RecipeScaler.scale(recipe, toDose: 15.04)
    #expect(scaled.recipe.doseG == 15)
    #expect(scaled.notes.contains("Dose is rounded to 0.1 g."))
  }

  @Test func invalidDosesAreRejected() {
    #expect(throws: RecipeScalerError.invalidDose) { try RecipeScaler.scale(recipe, toDose: 0) }
    #expect(throws: RecipeScalerError.invalidDose) { try RecipeScaler.scale(recipe, toDose: -5) }
    #expect(throws: RecipeScalerError.invalidDose) {
      try RecipeScaler.scale(recipe, toDose: .infinity)
    }
    var broken = recipe
    broken.doseG = 0
    #expect(throws: RecipeScalerError.invalidRecipeDose) {
      try RecipeScaler.scale(broken, toDose: 15)
    }
  }
}

@Suite struct FreshnessTests {
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()

  private func day(_ offset: Int) -> Date {
    let base = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    return calendar.date(byAdding: .day, value: offset, to: base)!
  }

  @Test func noRoastDateIsUnknown() {
    #expect(Freshness.state(roastDate: nil, today: day(10), calendar: calendar) == .unknown)
    #expect(Freshness.ageDays(roastDate: nil, today: day(10), calendar: calendar) == nil)
  }

  @Test func futureRoastDateIsUnknown() {
    #expect(Freshness.state(roastDate: day(5), today: day(1), calendar: calendar) == .unknown)
  }

  @Test func windowsFromRoastDate() {
    func state(_ age: Int) -> FreshnessState {
      Freshness.state(roastDate: day(0), today: day(age), calendar: calendar)
    }
    #expect(state(0) == .resting)
    #expect(state(4) == .resting)
    #expect(state(5) == .peak)
    #expect(state(30) == .peak)
    #expect(state(31) == .pastPeak)
  }

  @Test func timeOfDayDoesNotChangeTheDayCount() {
    let lateRoast = day(0).addingTimeInterval(23 * 3600)
    let earlyToday = day(5).addingTimeInterval(60)
    #expect(Freshness.ageDays(roastDate: lateRoast, today: earlyToday, calendar: calendar) == 5)
  }

  @Test func frozenDaysAreExcludedFromAge() {
    let spans = [FrozenSpan(frozenOn: day(3), thawedOn: day(33))]
    #expect(
      Freshness.ageDays(roastDate: day(0), frozenSpans: spans, today: day(40), calendar: calendar)
        == 10)
    #expect(
      Freshness.state(roastDate: day(0), frozenSpans: spans, today: day(40), calendar: calendar)
        == .peak)
  }

  @Test func currentlyFrozenBagIsFrozenAndKeepsItsAge() {
    let spans = [FrozenSpan(frozenOn: day(10))]
    #expect(
      Freshness.state(roastDate: day(0), frozenSpans: spans, today: day(60), calendar: calendar)
        == .frozen)
    #expect(
      Freshness.ageDays(roastDate: day(0), frozenSpans: spans, today: day(60), calendar: calendar)
        == 10)
  }

  @Test func multipleSpansAndSpansBeforeRoastAreClipped() {
    let spans = [
      FrozenSpan(frozenOn: day(-5), thawedOn: day(2)),
      FrozenSpan(frozenOn: day(10), thawedOn: day(14)),
    ]
    #expect(
      Freshness.ageDays(roastDate: day(0), frozenSpans: spans, today: day(20), calendar: calendar)
        == 14)
  }
}

@Suite struct UnitsTests {
  @Test func metricIsIdentity() {
    let units = UnitPreferences()
    #expect(units.displayWeight(grams: 18) == 18)
    #expect(units.displayTemperature(celsius: 93) == 93)
    #expect(units.weightSymbol == "g")
    #expect(units.temperatureSymbol == "°C")
  }

  @Test func ounceAndFahrenheitKnownValues() {
    let units = UnitPreferences(weight: .ounces, temperature: .fahrenheit)
    #expect(abs(units.displayWeight(grams: 28.349523125) - 1) < 1e-12)
    #expect(units.displayTemperature(celsius: 100) == 212)
    #expect(units.displayTemperature(celsius: 0) == 32)
    #expect(units.weightSymbol == "oz")
    #expect(units.temperatureSymbol == "°F")
  }

  @Test func roundTripsAreLossless() {
    let imperial = UnitPreferences(weight: .ounces, temperature: .fahrenheit)
    for grams in stride(from: 0.5, through: 1000, by: 37.3) {
      #expect(
        abs(imperial.grams(fromDisplayWeight: imperial.displayWeight(grams: grams)) - grams) < 1e-9)
    }
    for celsius in stride(from: -10.0, through: 100, by: 7.7) {
      let back = imperial.celsius(
        fromDisplayTemperature: imperial.displayTemperature(celsius: celsius))
      #expect(abs(back - celsius) < 1e-9)
    }
  }
}
