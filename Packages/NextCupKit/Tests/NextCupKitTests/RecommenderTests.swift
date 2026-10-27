import Foundation
import Testing

@testable import NextCupKit

@Suite("Recommender")
struct RecommenderTests {
  static let eastAfrica = BucketRef(dimension: .origin, key: "east-africa", name: "East Africa")
  static let washed = BucketRef(dimension: .process, key: "washed", name: "Washed")
  static let natural = BucketRef(dimension: .process, key: "natural", name: "Natural")
  static let light = BucketRef(dimension: .roast, key: "light", name: "Light")
  static let dark = BucketRef(dimension: .roast, key: "dark", name: "Dark")
  static let citrus = BucketRef(dimension: .flavor, key: "citrus", name: "Citrus")

  static func day(_ offset: Int) -> Date {
    Date(timeIntervalSince1970: 1_700_000_000 + Double(offset) * 86_400)
  }

  func brew(
    _ method: String, key: String? = nil, grade: Int?, day offset: Int = 0,
    buckets: [BucketRef] = [eastAfrica, washed, light], grind: String? = nil
  ) -> RecommenderBrew {
    RecommenderBrew(
      date: Self.day(offset), ratingTenths: grade, methodKey: key, methodName: method,
      doseG: 15, waterG: 250, tempC: 94, totalTimeS: 170, grindSetting: grind, buckets: buckets)
  }

  let bean = [eastAfrica, washed, light, citrus]

  @Test func ranksMethodsByAverageGrade() {
    let history = [
      brew("Cone dripper", key: "cone-dripper", grade: 9, day: 1),
      brew("Cone dripper", key: "cone-dripper", grade: 8, day: 2),
      brew("Press pot", key: "press", grade: 6, day: 3),
      brew("Press pot", key: "press", grade: 5, day: 4),
    ]
    let result = Recommender.recommend(for: bean, history: history)
    #expect(!result.isDefault)
    #expect(result.items.map(\.methodName) == ["Cone dripper", "Press pot"])
    #expect(result.similarRatedCount == 4)
  }

  @Test func equalAveragesBreakTiesByBrewCountThenRecency() {
    let history = [
      brew("A", key: "a", grade: 8, day: 1),
      brew("B", key: "b", grade: 8, day: 2),
      brew("B", key: "b", grade: 8, day: 3),
      brew("C", key: "c", grade: 8, day: 9),
    ]
    let names = Recommender.recommend(for: bean, history: history).items.map(\.methodName)
    #expect(names == ["B", "C", "A"])
  }

  @Test func startParametersComeFromTheBestBrewOfTheMethod() {
    var best = brew("Cone dripper", key: "cone-dripper", grade: 10, day: 5, grind: " 21 clicks ")
    best.doseG = 16
    best.tempC = 95
    let history = [
      brew("Cone dripper", key: "cone-dripper", grade: 7, day: 6, grind: "30"),
      best,
      brew("Cone dripper", key: "cone-dripper", grade: 8, day: 7, grind: "25"),
    ]
    let item = Recommender.recommend(for: bean, history: history).items[0]
    #expect(item.start.doseG == 16)
    #expect(item.start.tempC == 95)
    #expect(item.start.grindSetting == "21 clicks")
  }

  @Test func explanationUsesOnlyComputedFacts() {
    let history = [
      brew("Cone dripper", key: "cone-dripper", grade: 90, day: 1),
      brew("Cone dripper", key: "cone-dripper", grade: 80, day: 2),
      brew("Cone dripper", key: "cone-dripper", grade: 70, day: 3),
    ]
    let item = Recommender.recommend(for: bean, history: history).items[0]
    guard case .history(let facts) = item.basis else {
      Issue.record("expected history")
      return
    }
    #expect(facts.methodBrews == 3)
    #expect(facts.similarBrews == 3)
    #expect(facts.averageTenths == 80)
    #expect(facts.bestTenths == 90)
    #expect(facts.sharedBuckets == ["East Africa", "Washed", "Light"])
    #expect(
      item.explanation
        == "Your 3 brews with beans like this (East Africa, Washed, Light) averaged 8 of 10; the best was 9."
    )
  }

  @Test func explanationSaysWhenTheMethodIsPartOfALargerSet() {
    let history = [
      brew("Cone dripper", key: "cone-dripper", grade: 9, day: 1),
      brew("Press pot", key: "press", grade: 6, day: 2),
      brew("Press pot", key: "press", grade: 6, day: 3),
    ]
    let item = Recommender.recommend(for: bean, history: history).items[0]
    #expect(item.explanation.hasPrefix("Your 1 brew of 3 similar rated brews"))
  }

  @Test func fewerThanThreeSimilarRatedBrewsFallBackToTheLabelledDefault() {
    let history = [
      brew("Press pot", key: "press", grade: 10, day: 1),
      brew("Press pot", key: "press", grade: 10, day: 2),
    ]
    let result = Recommender.recommend(for: bean, history: history)
    #expect(result.isDefault)
    #expect(result.items.count == 1)
    #expect(result.items[0].methodKey == "cone-dripper")
    #expect(result.items[0].isDefault)
    #expect(result.items[0].explanation.contains("not based on your brews"))
    #expect(result.items[0].explanation.contains("light roasts"))
    #expect(result.similarRatedCount == 2)
  }

  @Test func coldStartWithNoHistoryUsesTheRoastBand() {
    let dark = Recommender.recommend(for: [Self.dark], history: [])
    #expect(dark.isDefault)
    #expect(dark.items[0].methodKey == "press")
    #expect(dark.items[0].start.tempC == 90)
  }

  @Test func beanWithoutRoastLevelGetsTheMediumDefaultAndSaysSo() {
    let result = Recommender.recommend(for: [Self.eastAfrica], history: [])
    #expect(result.isDefault)
    #expect(result.items[0].start.tempC == 93)
    #expect(result.items[0].explanation.contains("no roast level"))
  }

  @Test func unratedAndDissimilarBrewsDoNotCount() {
    let history = [
      brew("Cone dripper", key: "cone-dripper", grade: nil, day: 1),
      brew("Cone dripper", key: "cone-dripper", grade: 0, day: 2),
      brew(
        "Cone dripper", key: "cone-dripper", grade: 9, day: 3, buckets: [Self.dark, Self.natural]),
      brew("Cone dripper", key: "cone-dripper", grade: 9, day: 4, buckets: [Self.light]),
    ]
    let result = Recommender.recommend(for: bean, history: history)
    #expect(result.isDefault)
    #expect(result.similarRatedCount == 0)
  }

  @Test func flavorBucketsAloneNeverMakeBrewsSimilar() {
    let history = (1...4).map {
      brew("Cone dripper", key: "cone-dripper", grade: 9, day: $0, buckets: [Self.citrus])
    }
    #expect(Recommender.recommend(for: [Self.citrus], history: history).isDefault)
  }

  @Test func aBeanWithOnlyARoastLevelMatchesOnThatRoast() {
    let history = (1...3).map {
      brew("Press pot", key: "press", grade: 8, day: $0, buckets: [Self.dark])
    }
    let result = Recommender.recommend(for: [Self.dark], history: history)
    #expect(!result.isDefault)
    #expect(result.items[0].methodName == "Press pot")
  }

  @Test func customMethodsGroupByNormalizedName() {
    let history = [
      brew("Moka  Pot", grade: 8, day: 1),
      brew("moka pot", grade: 9, day: 2),
      brew("MOKA-POT", grade: 7, day: 3),
    ]
    let items = Recommender.recommend(for: bean, history: history).items
    #expect(items.count == 1)
    #expect(items[0].methodKey == nil)
    #expect(items[0].start.doseG == 15)
  }

  @Test func limitCapsTheList() {
    let history = (1...6).map { brew("M\($0 % 4)", key: "m\($0 % 4)", grade: 8, day: $0) }
    #expect(Recommender.recommend(for: bean, history: history, limit: 2).items.count == 2)
  }

  @Test func sameInputGivesTheSameOrder() {
    let history = (1...8).map { brew("M\($0 % 3)", key: "m\($0 % 3)", grade: 8, day: 1) }
    let first = Recommender.recommend(for: bean, history: history)
    for _ in 0..<5 { #expect(Recommender.recommend(for: bean, history: history) == first) }
  }
}
