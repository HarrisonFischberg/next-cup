import Testing

@testable import NextCupKit

struct RecipeTimingTests {
  @Test func steepsKeepTheirTime() {
    #expect(RecipeTiming.factor(isPourOver: false, recipeDoseG: 18, doseG: 40) == 1)
    #expect(RecipeTiming.scaled(210, by: 1) == 210)
  }

  @Test func pourOverStretchesGentlyAndWithinLimits() {
    let double = RecipeTiming.factor(isPourOver: true, recipeDoseG: 15, doseG: 30)
    #expect(double > 1.4 && double < 1.42)
    #expect(RecipeTiming.factor(isPourOver: true, recipeDoseG: 15, doseG: 60) == 1.6)
    #expect(RecipeTiming.factor(isPourOver: true, recipeDoseG: 30, doseG: 5) == 0.75)
    #expect(RecipeTiming.scaled(180, by: double) == 255)
  }
}
