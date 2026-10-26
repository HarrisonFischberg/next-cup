import Testing

@testable import NextCupKit

struct GrinderGuideTests {
  @Test func listsTheTwentyOneGrindersOnceEach() {
    #expect(GrinderGuide.all.count == 21)
    #expect(Set(GrinderGuide.all.map(\.name)).count == 21)
    #expect(GrinderGuide.all.allSatisfy { $0.source.hasPrefix("https://honestcoffeeguide.com/") })
  }

  @Test func everyGrinderHasAPourOverRange() {
    #expect(GrinderGuide.all.allSatisfy { $0.pourOver?.isEmpty == false })
  }

  @Test func brewOnlyGrindersHaveNoEspressoRange() {
    for name in ["Baratza Encore", "Fellow Ode Gen 2", "Timemore Chestnut S3"] {
      #expect(GrinderGuide.find(name)?.espresso == nil)
    }
    #expect(GrinderGuide.find("Niche Zero")?.espresso != nil)
  }

  @Test func findsByLooseName() {
    #expect(GrinderGuide.find("comandante c40 mk4")?.notation == "clicks")
    #expect(GrinderGuide.find("My grinder") == nil)
    #expect(GrinderGuide.find(nil) == nil)
  }

  @Test func mapsTheAppsMethodNames() {
    #expect(GrinderGuide.method(forMethodNamed: "Cone dripper") == .pourOver)
    #expect(GrinderGuide.method(forMethodNamed: "Switchable immersion dripper") == .pourOver)
    #expect(GrinderGuide.method(forMethodNamed: "Press pot") == .frenchPress)
    #expect(GrinderGuide.method(forMethodNamed: "Inverted press") == .aeroPress)
    #expect(GrinderGuide.method(forMethodNamed: "Espresso") == .espresso)
    #expect(GrinderGuide.method(forMethodNamed: "Cold brew") == .coldBrew)
    #expect(GrinderGuide.method(forMethodNamed: "Siphon") == nil)
  }

  @Test func recommendsOneSetting() {
    #expect(GrinderGuide.find("Comandante C40 MK4")?.recommended(for: .pourOver) == "20")
    #expect(GrinderGuide.find("Niche Zero")?.recommended(for: .pourOver) == "0.45")
    #expect(GrinderGuide.find("1Zpresso K-Ultra")?.recommended(for: .pourOver) == "0.5.3")
    #expect(GrinderGuide.find("Baratza Encore")?.recommended(for: .espresso) == nil)
  }
}
