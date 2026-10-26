import Foundation
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Beans")
struct BeanTests {
  @MainActor
  private struct Harness {
    let container: ModelContainer
    let service: BeanService
    var context: ModelContext { container.mainContext }

    init() throws {
      container = try NextCupContainer.make(inMemory: true)
      service = BeanService(store: Store(context: container.mainContext))
    }

    @discardableResult
    func add(_ name: String, configure: (inout BeanFields) -> Void = { _ in }) throws -> Bean {
      var fields = BeanFields()
      fields.name = name
      configure(&fields)
      return try service.save(fields).get()
    }

    /// Logs a brew that took `grams` from the bean.
    func brew(_ bean: Bean, grams: Double) throws {
      let brew = Brew()
      context.insert(brew)
      let use = BrewBean(grams: grams, beanNameSnapshot: bean.name)
      context.insert(use)
      use.brew = brew
      use.bean = bean
      try context.save()
    }
  }

  private func failure<T>(_ result: Result<T, BeanError>) -> BeanError? {
    if case .failure(let error) = result { return error }
    return nil
  }

  // MARK: Service

  @Test func changedCountCountsOnlyTheFieldsAScanFilled() {
    var before = BeanFields()
    before.name = "Guji"
    var after = before
    #expect(before.changedCount(to: after) == 0)
    after.roasterName = "Onyx"
    after.originCountry = "Ethiopia"
    after.roastDate = Date(timeIntervalSince1970: 0)
    #expect(before.changedCount(to: after) == 3)
  }

  @Test func savingAddsABeanWithItsFieldsTrimmed() throws {
    let harness = try Harness()
    let bean = try harness.add("  Washed Ethiopia  ") {
      $0.originCountry = " Ethiopia "
      $0.region = "   "
      $0.flavorNotes = "jasmine, Peach; honey\npeach"
      $0.bagWeightG = 250
      $0.roastLevel = .light
    }
    #expect(bean.name == "Washed Ethiopia")
    #expect(bean.originCountry == "Ethiopia")
    #expect(bean.region == nil)
    #expect(bean.bagFlavorNotes == ["jasmine", "Peach", "honey"])
    #expect(bean.bagWeightG == 250)
    #expect(bean.roastLevel == .light)
  }

  @Test func rejectsAnEmptyNameAndANonPositiveBagWeight() throws {
    let harness = try Harness()
    var fields = BeanFields()
    fields.name = "   "
    #expect(failure(harness.service.save(fields)) == .emptyName)
    fields.name = "Okay"
    fields.bagWeightG = 0
    #expect(failure(harness.service.save(fields)) == .invalidBagWeight)
    #expect(try harness.context.fetch(FetchDescriptor<Bean>()).isEmpty)
  }

  @Test func roasterIsReusedByNameAnyCaseAndNeverDuplicated() throws {
    let harness = try Harness()
    let first = try harness.add("One") { $0.roasterName = "Tiny Roastery" }
    let second = try harness.add("Two") { $0.roasterName = "  tiny roastery " }
    #expect(first.roaster?.id == second.roaster?.id)
    #expect(try harness.context.fetch(FetchDescriptor<Roaster>()).count == 1)
    let none = try harness.add("Three")
    #expect(none.roaster == nil)
  }

  @Test func editingChangesTheSameBean() throws {
    let harness = try Harness()
    let bean = try harness.add("Old name")
    var fields = BeanFields(bean)
    fields.name = "New name"
    fields.status = .buyAgain
    let saved = try harness.service.save(fields, editing: bean).get()
    #expect(saved.id == bean.id)
    #expect(saved.name == "New name")
    #expect(saved.status == .buyAgain)
    #expect(try harness.context.fetch(FetchDescriptor<Bean>()).count == 1)
  }

  @Test func deletingABeanKeepsItsBrewsWithTheNameAsLogged() throws {
    let harness = try Harness()
    let bean = try harness.add("Gone") { $0.bagWeightG = 250 }
    try harness.brew(bean, grams: 15)
    try harness.service.delete(bean).get()
    #expect(try harness.context.fetch(FetchDescriptor<Bean>()).isEmpty)
    let brews = try harness.context.fetch(FetchDescriptor<Brew>())
    #expect(brews.count == 1)
    #expect(brews.first?.beanNames == ["Gone"])
  }

  // MARK: Remaining stock

  @Test func remainingDropsWithEachBrewAndFollowsManualCorrections() throws {
    let harness = try Harness()
    let bean = try harness.add("Bag") { $0.bagWeightG = 250 }
    #expect(bean.remainingG == 250)
    try harness.brew(bean, grams: 15)
    try harness.brew(bean, grams: 18)
    #expect(bean.remainingG == 217)

    try harness.service.setRemaining(bean, grams: 140).get()
    #expect(bean.remainingG == 140)
    #expect(bean.remainingAdjustmentG == -77)

    // A later brew still comes off the corrected amount.
    try harness.brew(bean, grams: 20)
    #expect(bean.remainingG == 120)
  }

  @Test func remainingIsUnknownWithoutABagWeightAndCannotBeCorrected() throws {
    let harness = try Harness()
    let bean = try harness.add("No weight")
    #expect(bean.remainingG == nil)
    #expect(bean.stockLevel == .unknown)
    #expect(failure(harness.service.setRemaining(bean, grams: 50)) == .invalidRemaining)
  }

  @Test func stockLevelFlagsLowAndEmptyBags() throws {
    let harness = try Harness()
    let bean = try harness.add("Bag") { $0.bagWeightG = 100 }
    try harness.brew(bean, grams: 85)
    #expect(bean.stockLevel == .low)
    try harness.brew(bean, grams: 30)
    #expect(bean.remainingG == 0)
    #expect(bean.stockLevel == .empty)
  }

  // MARK: Freshness

  @Test func freshnessUsesTheRoastDateAndSkipsFrozenDays() throws {
    let harness = try Harness()
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: today)! }

    let fresh = try harness.add("Fresh") { $0.roastDate = daysAgo(2) }
    #expect(fresh.freshness(today: today) == .resting)
    let peak = try harness.add("Peak") { $0.roastDate = daysAgo(12) }
    #expect(peak.freshness(today: today) == .peak)
    #expect(peak.ageDays(today: today) == 12)
    let old = try harness.add("Old") { $0.roastDate = daysAgo(60) }
    #expect(old.freshness(today: today) == .pastPeak)
    let unknown = try harness.add("Unknown")
    #expect(unknown.freshness(today: today) == .unknown)

    // Frozen for 40 of 60 days: only 20 days of aging.
    old.frozenOn = daysAgo(50)
    old.thawedOn = daysAgo(10)
    #expect(old.ageDays(today: today) == 20)
    #expect(old.freshness(today: today) == .peak)
    old.thawedOn = nil
    #expect(old.freshness(today: today) == .frozen)
  }

  // MARK: Filter and sort

  private func library() throws -> (Harness, [Bean]) {
    let harness = try Harness()
    let calendar = Calendar.current
    let beans = [
      try harness.add("Bravo Natural") {
        $0.roasterName = "Alpha Roasters"
        $0.originCountry = "Ethiopia"
        $0.process = "Natural"
        $0.status = .inUse
        $0.roastDate = calendar.date(byAdding: .day, value: -3, to: Date())
      },
      try harness.add("Charlie Washed") {
        $0.roasterName = "Beta Coffee"
        $0.originCountry = "Colombia"
        $0.flavorNotes = "caramel, red apple"
        $0.status = .buyAgain
        $0.roastDate = calendar.date(byAdding: .day, value: -20, to: Date())
      },
      try harness.add("Alpha Honey") {
        $0.originCountry = "Costa Rica"
        $0.status = .wishlist
      },
    ]
    beans[0].ratingHalfSteps = 6
    beans[1].ratingHalfSteps = 9
    // Distinct creation times make "recent" deterministic.
    for (index, bean) in beans.enumerated() {
      bean.createdAt = Date(timeIntervalSince1970: Double(1000 + index))
    }
    return (harness, beans)
  }

  @Test func statusFilterKeepsOnlyThatStatus() throws {
    let (harness, beans) = try library()
    defer { withExtendedLifetime(harness) {} }
    var filter = BeanFilter()
    #expect(filter.apply(to: beans).count == 3)
    filter.status = .buyAgain
    #expect(filter.apply(to: beans).map(\.name) == ["Charlie Washed"])
    filter.status = .wishlist
    #expect(filter.apply(to: beans).map(\.name) == ["Alpha Honey"])
    filter.status = .finished
    #expect(filter.apply(to: beans).isEmpty)
    #expect(filter.isNarrowing)
  }

  @Test func searchLooksAtNameRoasterOriginProcessAndFlavorNotes() throws {
    let (harness, beans) = try library()
    defer { withExtendedLifetime(harness) {} }
    var filter = BeanFilter()
    for (term, expected) in [
      ("bravo", "Bravo Natural"), ("beta", "Charlie Washed"), ("costa", "Alpha Honey"),
      ("natural", "Bravo Natural"), ("apple", "Charlie Washed"),
    ] {
      filter.search = term
      #expect(filter.apply(to: beans).map(\.name).first == expected, "search \(term)")
    }
    filter.search = "zzzz"
    #expect(filter.apply(to: beans).isEmpty)
    filter.search = "   "
    #expect(filter.apply(to: beans).count == 3)
    #expect(!filter.isNarrowing)
  }

  @Test func sortsByRecentNameRoastDateAndGrade() throws {
    let (harness, beans) = try library()
    defer { withExtendedLifetime(harness) {} }
    var filter = BeanFilter()
    #expect(
      filter.apply(to: beans).map(\.name) == ["Alpha Honey", "Charlie Washed", "Bravo Natural"])
    filter.sort = .name
    #expect(
      filter.apply(to: beans).map(\.name) == ["Alpha Honey", "Bravo Natural", "Charlie Washed"])
    filter.sort = .roastDate  // newest roast first, no roast date last
    #expect(
      filter.apply(to: beans).map(\.name) == ["Bravo Natural", "Charlie Washed", "Alpha Honey"])
    filter.sort = .grade
    #expect(
      filter.apply(to: beans).map(\.name) == ["Charlie Washed", "Bravo Natural", "Alpha Honey"])
  }

  @Test func filterAndSortChoicesAreRememberedByKey() {
    let defaults = UserDefaults(suiteName: "BeanTests.remember")!
    defer { defaults.removePersistentDomain(forName: "BeanTests.remember") }
    defaults.set(BeanStatusFilter.wishlist.rawValue, forKey: BeanStorage.statusKey)
    defaults.set(BeanSort.name.rawValue, forKey: BeanStorage.sortKey)
    #expect(
      BeanStatusFilter(rawValue: defaults.string(forKey: BeanStorage.statusKey) ?? "") == .wishlist)
    #expect(BeanSort(rawValue: defaults.string(forKey: BeanStorage.sortKey) ?? "") == .name)
    BeanStorage.reset(defaults)
    #expect(defaults.string(forKey: BeanStorage.statusKey) == nil)
    #expect(defaults.string(forKey: BeanStorage.sortKey) == nil)
  }
}
