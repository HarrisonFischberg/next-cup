import Testing

@testable import NextCupKit

@Suite("Bean stock")
struct BeanStockTests {
  @Test func remainingIsBagMinusEveryBrew() {
    let left = BeanStock.remainingG(bagWeightG: 250, usedG: [15, 18, 20])
    #expect(left == 197)
  }

  @Test func blendShareCountsAgainstEachBean() {
    // A 20 g blend brew of two beans uses 12 g of one and 8 g of the other.
    #expect(BeanStock.remainingG(bagWeightG: 250, usedG: [12]) == 238)
    #expect(BeanStock.remainingG(bagWeightG: 250, usedG: [8]) == 242)
  }

  @Test func manualAdjustmentAddsAndSubtracts() {
    #expect(BeanStock.remainingG(bagWeightG: 250, usedG: [50], adjustmentG: -20) == 180)
    #expect(BeanStock.remainingG(bagWeightG: 250, usedG: [50], adjustmentG: 10) == 210)
  }

  @Test func neverBelowZero() {
    #expect(BeanStock.remainingG(bagWeightG: 100, usedG: [60, 60]) == 0)
    #expect(BeanStock.remainingG(bagWeightG: 100, usedG: [], adjustmentG: -500) == 0)
  }

  @Test func unknownWithoutABagWeight() {
    #expect(BeanStock.remainingG(bagWeightG: nil, usedG: [15]) == nil)
    #expect(BeanStock.remainingG(bagWeightG: 0, usedG: [15]) == nil)
  }

  @Test func settingTheRemainingAmountRoundTrips() throws {
    let adjustment = try #require(
      BeanStock.adjustmentG(settingRemainingTo: 140, bagWeightG: 250, usedG: [15, 18]))
    #expect(
      BeanStock.remainingG(bagWeightG: 250, usedG: [15, 18], adjustmentG: adjustment) == 140)
    #expect(BeanStock.adjustmentG(settingRemainingTo: 10, bagWeightG: nil, usedG: []) == nil)
    #expect(BeanStock.adjustmentG(settingRemainingTo: -1, bagWeightG: 250, usedG: []) == nil)
  }

  @Test func levelsFollowTheShareLeft() {
    #expect(BeanStock.level(remainingG: nil, bagWeightG: nil) == .unknown)
    #expect(BeanStock.level(remainingG: 0, bagWeightG: 250) == .empty)
    #expect(BeanStock.level(remainingG: 50, bagWeightG: 250) == .low)
    #expect(BeanStock.level(remainingG: 51, bagWeightG: 250) == .ok)
  }
}
