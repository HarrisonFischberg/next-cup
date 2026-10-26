import Testing

@testable import NextCup

@Suite("Popular beans")
struct PopularBeansTests {
  @Test func offersAboutAHundredCoffeesOnceEach() {
    let all = PopularBeans.all
    #expect(all.count >= 100)
    #expect(Set(all.map(\.id)).count == all.count)
    #expect(all.allSatisfy { !$0.roaster.isEmpty && !$0.coffee.isEmpty })
  }

  @Test func searchMatchesRoasterOrCoffeeIgnoringCase() {
    #expect(PopularBeans.search("hair bender").contains { $0.roaster == "Stumptown" })
    #expect(PopularBeans.search("ONYX").allSatisfy { $0.roaster == "Onyx Coffee Lab" })
    #expect(PopularBeans.search("zzzz").isEmpty)
    #expect(PopularBeans.search("  ").count == PopularBeans.all.count)
  }

  @Test func starbucksComesLast() {
    let all = PopularBeans.all
    let first = try? #require(all.firstIndex { $0.roaster == "Starbucks" })
    #expect(first.map { all[$0...].allSatisfy { $0.roaster == "Starbucks" } } == true)
  }
}
