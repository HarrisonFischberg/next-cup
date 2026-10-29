import Testing

@testable import NextCup

@Suite("Brew amount")
struct BrewYieldTests {
  @Test func readsLikeTheWheelInEachUnit() {
    // 15 g : 250 g keeps 30 g in the grounds, so it makes 220 ml.
    #expect(BrewYield.ml.amountText(doseG: 15, waterG: 250) == "220 ml")
    #expect(BrewYield.oz.amountText(doseG: 15, waterG: 250) == "7 oz")
    #expect(BrewYield.cups.amountText(doseG: 15, waterG: 250) == "0.9 cups")
  }

  @Test func anAmountPickedOnTheWheelComesBack() {
    let ratio = 250.0 / 15
    let dose = 12 * BrewYield.oz.millilitres / (ratio - 2)
    #expect(BrewYield.oz.amountText(doseG: dose, waterG: dose * ratio) == "12 oz")
  }

  @Test func needsBothDoseAndWater() {
    #expect(BrewYield.oz.amountText(doseG: nil, waterG: 250) == nil)
    #expect(BrewYield.oz.amountText(doseG: 15, waterG: nil) == nil)
  }
}
