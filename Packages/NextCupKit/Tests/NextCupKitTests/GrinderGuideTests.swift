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

  @Test func everyRecommendedSettingIsOnItsGrindersWheel() {
    for guide in GrinderGuide.all {
      let settings = Set(guide.settings)
      #expect(settings.count == guide.settings.count, "\(guide.name) repeats a setting")
      for method in [
        GrinderGuide.Method.pourOver, .aeroPress, .frenchPress, .moka, .espresso, .coldBrew,
      ] {
        guard let start = guide.recommended(for: method) else { continue }
        #expect(
          GrinderGuide.setting(start, in: guide.settings) != nil,
          "\(guide.name) \(method): \(start)")
      }
    }
    #expect(GrinderGuide.find("Comandante C40 MK4")?.settings.last == "40")
    #expect(GrinderGuide.find("Fellow Ode Gen 2")?.settings.contains("3.7") == true)
    #expect(GrinderGuide.otherSettings.first == "0" && GrinderGuide.otherSettings.last == "40")
  }
}
