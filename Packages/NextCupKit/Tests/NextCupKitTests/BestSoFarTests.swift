import Foundation
import Testing

@testable import NextCupKit

@Suite("Blend shares")
struct BlendSharesTests {
  @Test func evenSplitGivesEachBeanTheSameShare() {
    #expect(BlendShares.grams(dose: 20, parts: [1, 1]) == [10, 10])
  }

  @Test func partsSetTheShares() {
    #expect(BlendShares.grams(dose: 20, parts: [3, 2]) == [12, 8])
  }

  @Test func thirdsStillAddUpToTheDose() {
    let shares = BlendShares.grams(dose: 20, parts: [1, 1, 1])
    #expect(shares.count == 3)
    #expect((shares.reduce(0, +) * 100).rounded() == 2000)
  }

  @Test func singleBeanTakesTheWholeDose() {
    #expect(BlendShares.grams(dose: 15.5, parts: [1]) == [15.5])
  }

  @Test func zeroPartsFallBackToAnEvenSplit() {
    #expect(BlendShares.grams(dose: 18, parts: [0, 0]) == [9, 9])
    #expect(BlendShares.grams(dose: 18, parts: [-1, .nan]) == [9, 9])
  }

  @Test func noDoseOrNoBeansGivesZeros() {
    #expect(BlendShares.grams(dose: 0, parts: [1, 1]) == [0, 0])
    #expect(BlendShares.grams(dose: 18, parts: []).isEmpty)
  }

  private func total(_ shares: [Double]) -> Double { shares.reduce(0, +) }

  @Test func percentagesAddUpToOneHundred() {
    #expect(BlendShares.percentages(parts: [3, 1]) == [75, 25])
    #expect(BlendShares.percentages(parts: [0, 0]) == [50, 50])
    #expect(BlendShares.percentages(parts: []).isEmpty)
  }

  @Test func addingABeanStartsItAtAnEvenShare() {
    #expect(BlendShares.appending(to: []) == [100])
    #expect(BlendShares.appending(to: [100]) == [50, 50])
    let three = BlendShares.appending(to: [60, 40])
    #expect(abs(three[2] - 100.0 / 3.0) < 0.0001)
    #expect(abs(three[0] - 40) < 0.0001)
    #expect(abs(total(three) - 100) < 0.0001)
  }

  @Test func removingABeanGivesItsShareToTheOthers() {
    let rest = BlendShares.removing(at: 1, from: [50, 30, 20])
    #expect(rest.count == 2)
    #expect(abs(rest[0] - 500.0 / 7.0) < 0.0001)  // 50 of the remaining 70
    #expect(abs(total(rest) - 100) < 0.0001)
    #expect(BlendShares.removing(at: 0, from: [100]).isEmpty)
  }

  @Test func rebalancingKeepsTheTotalAndTheOthersInProportion() {
    let result = BlendShares.rebalanced([50, 30, 20], setting: 0, to: 70)
    #expect(result[0] == 70)
    #expect(abs(result[1] - 18) < 0.0001)
    #expect(abs(result[2] - 12) < 0.0001)
    #expect(abs(total(result) - 100) < 0.0001)
  }

  @Test func aShareCannotDropOrTakeEverything() {
    #expect(BlendShares.rebalanced([50, 50], setting: 0, to: 0) == [5, 95])
    #expect(BlendShares.rebalanced([50, 50], setting: 0, to: 100) == [95, 5])
    #expect(BlendShares.rebalanced([100], setting: 0, to: 40) == [100])
  }
}

@Suite("Best so far")
struct BestSoFarTests {
  private func day(_ offset: Int) -> Date {
    Date(timeIntervalSince1970: 1_700_000_000 + Double(offset) * 86400)
  }

  @Test func noBrewsGivesAnEmptySummary() {
    let summary = BestSoFar.summarize([])
    #expect(summary.brewCount == 0)
    #expect(summary.ratedCount == 0)
    #expect(summary.spread.isEmpty)
    #expect(summary.averageHalfSteps == nil)
    #expect(summary.best == nil)
    #expect(summary.grindHistory.isEmpty)
  }

  @Test func spreadCountsEachGradeAndIgnoresUnrated() throws {
    let summary = BestSoFar.summarize([
      BrewSample(date: day(0), ratingHalfSteps: 6),
      BrewSample(date: day(1), ratingHalfSteps: 8),
      BrewSample(date: day(2), ratingHalfSteps: 6),
      BrewSample(date: day(3), ratingHalfSteps: nil),
      BrewSample(date: day(4), ratingHalfSteps: 0),
    ])
    #expect(summary.brewCount == 5)
    #expect(summary.ratedCount == 3)
    #expect(
      summary.spread == [RatingCount(halfSteps: 6, brews: 2), RatingCount(halfSteps: 8, brews: 1)])
    let average = try #require(summary.averageHalfSteps)
    #expect(abs(average - 20.0 / 3.0) < 0.0001)
  }

  @Test func bestIsTheHighestGradeAndTheNewestOfATie() {
    let older = BrewSample(
      date: day(0), ratingHalfSteps: 9, doseG: 15, waterG: 250, tempC: 94, totalTimeS: 170,
      grindSetting: "21")
    let newer = BrewSample(
      date: day(5), ratingHalfSteps: 9, doseG: 16, waterG: 260, tempC: 93, totalTimeS: 180,
      grindSetting: "22")
    let lower = BrewSample(date: day(9), ratingHalfSteps: 7, doseG: 15)
    let summary = BestSoFar.summarize([older, lower, newer])
    #expect(summary.best == newer)
  }

  @Test func noGradeMeansNoBest() {
    let summary = BestSoFar.summarize([BrewSample(date: day(0), grindSetting: "20")])
    #expect(summary.best == nil)
    #expect(summary.ratedCount == 0)
  }

  @Test func grindHistoryGroupsByGrinderDoseAndSetting() {
    let summary = BestSoFar.summarize([
      BrewSample(date: day(0), ratingHalfSteps: 6, doseG: 15, grindSetting: "21", grinder: "Zed"),
      BrewSample(
        date: day(1), ratingHalfSteps: 8, doseG: 15.04, grindSetting: "21", grinder: "Zed"),
      BrewSample(date: day(2), ratingHalfSteps: 9, doseG: 18, grindSetting: "23", grinder: "Zed"),
      BrewSample(date: day(3), ratingHalfSteps: 5, doseG: 15, grindSetting: "30", grinder: "Alma"),
      BrewSample(date: day(4), doseG: 15, grindSetting: "25"),
      BrewSample(date: day(5), ratingHalfSteps: 10, doseG: 15, grindSetting: "   "),
    ])
    let history = summary.grindHistory
    // Alma first, then Zed by dose, then the brew with no grinder recorded.
    #expect(history.map(\.grinder) == ["Alma", "Zed", "Zed", nil])
    #expect(history.map(\.setting) == ["30", "21", "23", "25"])
    let zed = history[1]
    #expect(zed.doseG == 15)
    #expect(zed.brews == 2)
    #expect(zed.averageHalfSteps == 7)
    #expect(zed.lastUsed == day(1))
    #expect(history[3].averageHalfSteps == nil)
  }
}
