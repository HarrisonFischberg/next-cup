import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Blends, freezer and best so far")
struct BlendAndFreezerTests {
  @MainActor
  private struct Harness {
    let container: ModelContainer
    let store: Store
    let beans: BeanService
    let draftStore: DraftStore
    let defaults: UserDefaults
    var context: ModelContext { container.mainContext }

    init() throws {
      container = try NextCupContainer.make(inMemory: true)
      store = Store(context: container.mainContext)
      beans = BeanService(store: store)
      draftStore = DraftStore(
        fileURL: FileManager.default.temporaryDirectory
          .appendingPathComponent("nextcup-blend-\(UUID().uuidString)/brew-draft.json"))
      defaults = UserDefaults(suiteName: "nextcup.blendtests.\(UUID().uuidString)") ?? .standard
    }

    func bean(_ name: String, bagG: Double? = 250, decaf: Bool = false) throws -> Bean {
      var fields = BeanFields()
      fields.name = name
      fields.bagWeightG = bagG
      fields.isDecaf = decaf
      return try beans.save(fields).get()
    }

    func model(editing: Brew? = nil) -> BrewFormModel {
      BrewFormModel(
        seed: nil, editing: editing, store: store, draftStore: draftStore, defaults: defaults)
    }

    func brews() throws -> [Brew] { try context.fetch(FetchDescriptor<Brew>()) }
  }

  private func day(_ offset: Int) -> Date {
    Calendar.current.date(
      byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date()))!
  }

  // MARK: Blend

  @Test func aBlendBrewDeductsEachBeansShareFromItsOwnBag() throws {
    let harness = try Harness()
    let ethiopia = try harness.bean("Ethiopia")
    let brazil = try harness.bean("Brazil")
    let model = harness.model()
    model.draft.doseG = 20
    model.draft.waterG = 320
    model.addBean(ethiopia)
    model.addBean(brazil)
    #expect(model.beanShares == [50, 50])

    model.stepShare(at: 0, by: 10)  // 60 / 40
    #expect(model.beanShares.map { $0.rounded() } == [60, 40])
    #expect(model.beanGrams == [12, 8])

    #expect(model.save())
    #expect(ethiopia.remainingG == 238)
    #expect(brazil.remainingG == 242)
    let brew = try #require(try harness.brews().first)
    #expect(brew.beans?.count == 2)
    #expect(Set(brew.beanNames) == ["Ethiopia", "Brazil"])
  }

  @Test func aHigherGradeThanEveryEarlierBrewOfTheBeanIsANewBest() throws {
    let harness = try Harness()
    let bean = try harness.bean("Guji")
    func brew(_ grade: Int) -> BrewFormModel {
      let model = harness.model()
      model.draft.doseG = 15
      model.draft.waterG = 250
      model.draft.ratingHalfSteps = grade
      model.addBean(bean)
      _ = model.save()
      return model
    }
    #expect(brew(14).newBest == nil, "a first brew has nothing to beat")
    let better = try #require(brew(17).newBest)
    #expect(better.bean == "Guji" && better.halfSteps == 17 && better.previous == 14)
    #expect(brew(12).newBest == nil)
  }

  @Test func aSingleBeanTakesTheWholeDose() throws {
    let harness = try Harness()
    let bean = try harness.bean("Solo")
    let model = harness.model()
    model.draft.doseG = 18
    model.draft.waterG = 288
    model.addBean(bean)
    model.addBean(bean)  // choosing it twice changes nothing
    #expect(model.draft.beans?.count == 1)
    #expect(model.save())
    #expect(bean.remainingG == 232)
  }

  @Test func removingABeanGivesItsShareBack() throws {
    let harness = try Harness()
    let model = harness.model()
    model.draft.doseG = 20
    model.addBean(try harness.bean("A"))
    model.addBean(try harness.bean("B"))
    model.removeBean(at: 0)
    #expect(model.draft.beans?.map(\.name) == ["B"])
    #expect(model.beanShares == [100])
    #expect(model.beanGrams == [20])
  }

  @Test func editingABlendReplacesItsBeansSoNoBagIsChargedTwice() throws {
    let harness = try Harness()
    let first = try harness.bean("First")
    let second = try harness.bean("Second")
    let create = harness.model()
    create.draft.doseG = 20
    create.draft.waterG = 320
    create.addBean(first)
    create.addBean(second)
    #expect(create.save())
    #expect(first.remainingG == 240)

    let brew = try #require(try harness.brews().first)
    let edit = harness.model(editing: brew)
    #expect(edit.draft.beans?.map(\.name) == ["First", "Second"])
    edit.draft.doseG = 30
    #expect(edit.save())
    // 30 g split evenly: 15 g from each bag, not 10 + 15.
    #expect(first.remainingG == 235)
    #expect(second.remainingG == 235)
    #expect(try harness.context.fetch(FetchDescriptor<BrewBean>()).count == 2)
  }

  @Test func decafBeansAreMarkedInTheBlend() throws {
    let harness = try Harness()
    let decaf = try harness.bean("Swiss water", decaf: true)
    #expect(decaf.isDecaf)
    var fields = BeanFields(decaf)
    fields.isDecaf = false
    let saved = try harness.beans.save(fields, editing: decaf).get()
    #expect(!saved.isDecaf)
  }

  // MARK: Grinder

  @Test func grinderIsChosenSavedAndRememberedForTheNextBrew() throws {
    let harness = try Harness()
    let model = harness.model()
    #expect(model.addGrinder(named: "  Hand mill "))
    #expect(!model.addGrinder(named: "   "))
    let id = try #require(model.draft.grinderID)
    #expect(model.addGrinder(named: "hand MILL"))
    #expect(model.draft.grinderID == id)
    #expect(try harness.context.fetch(FetchDescriptor<Grinder>()).count == 1)

    model.draft.doseG = 15
    model.draft.waterG = 250
    #expect(model.save())
    #expect(try harness.brews().first?.grinder?.name == "Hand mill")

    let next = BrewFormModel(
      seed: nil, store: harness.store,
      draftStore: DraftStore(
        fileURL: FileManager.default.temporaryDirectory
          .appendingPathComponent("nextcup-blend-\(UUID().uuidString)/brew-draft.json")),
      defaults: harness.defaults)
    #expect(next.draft.grinderID == id)
  }

  // MARK: Freezer

  @Test func freezingStopsAgeAndThawingResumesIt() throws {
    let harness = try Harness()
    let bean = try harness.bean("Frozen")
    bean.roastDate = day(-30)
    try harness.beans.freeze(bean, on: day(-20)).get()
    #expect(bean.isFrozen)
    #expect(bean.freshness(today: day(0)) == .frozen)
    #expect(bean.ageDays(today: day(0)) == 10)

    try harness.beans.thaw(bean, on: day(-5)).get()
    #expect(!bean.isFrozen)
    // 30 days since roast, 15 of them frozen.
    #expect(bean.ageDays(today: day(0)) == 15)
    #expect(bean.freshness(today: day(0)) == .peak)
  }

  @Test func freezerRulesAreEnforced() throws {
    let harness = try Harness()
    let bean = try harness.bean("Rules")
    #expect(failure(harness.beans.thaw(bean)) == .notFrozen)
    try harness.beans.freeze(bean, on: day(-4)).get()
    #expect(failure(harness.beans.freeze(bean)) == .alreadyFrozen)
    // A thaw dated before the freeze cannot run time backwards.
    try harness.beans.thaw(bean, on: day(-10)).get()
    #expect(bean.thawedOn == day(-4))
    #expect(failure(harness.beans.freeze(bean)) == .alreadyFrozenOnce)
    #expect(failure(harness.beans.thaw(bean)) == .notFrozen)
  }

  private func failure<T>(_ result: Result<T, BeanError>) -> BeanError? {
    if case .failure(let error) = result { return error }
    return nil
  }

  // MARK: Best so far

  @Test func bestSoFarReadsTheBeansBrewsAndGrinders() throws {
    let harness = try Harness()
    let bean = try harness.bean("Tracked")
    let grinder = Grinder(name: "Hand mill")
    harness.context.insert(grinder)

    func log(rating: Int?, dose: Double, grind: String, daysAgo: Int, draft: Bool = false) {
      let brew = Brew(date: day(-daysAgo))
      brew.doseG = dose
      brew.waterG = dose * 16
      brew.tempC = 94
      brew.totalTimeS = 180
      brew.grindSetting = grind
      brew.ratingHalfSteps = rating
      brew.isDraft = draft
      brew.grinder = grinder
      harness.context.insert(brew)
      let use = BrewBean(grams: dose, beanNameSnapshot: bean.name)
      harness.context.insert(use)
      use.brew = brew
      use.bean = bean
    }
    log(rating: 6, dose: 15, grind: "21", daysAgo: 6)
    log(rating: 9, dose: 15, grind: "23", daysAgo: 3)
    log(rating: 7, dose: 18, grind: "24", daysAgo: 1)
    log(rating: 10, dose: 15, grind: "99", daysAgo: 0, draft: true)
    try harness.context.save()

    let summary = bean.bestSoFar
    #expect(summary.brewCount == 3)  // the draft is not a brew yet
    #expect(summary.spread.map(\.halfSteps) == [6, 7, 9])
    #expect(summary.best?.grindSetting == "23")
    #expect(summary.best?.grinder == "Hand mill")
    // Same dose: newest first; then the larger dose.
    #expect(summary.grindHistory.map(\.setting) == ["23", "21", "24"])
    #expect(summary.grindHistory.map(\.doseG) == [15, 15, 18])
  }

  @Test func aBlendBrewCountsForEachBeanInIt() throws {
    let harness = try Harness()
    let one = try harness.bean("One")
    let two = try harness.bean("Two")
    let model = harness.model()
    model.draft.doseG = 20
    model.draft.waterG = 320
    model.draft.ratingHalfSteps = 8
    model.addBean(one)
    model.addBean(two)
    #expect(model.save())
    #expect(one.bestSoFar.best?.ratingHalfSteps == 8)
    #expect(two.bestSoFar.best?.ratingHalfSteps == 8)
    #expect(one.bestSoFar.brewCount == 1)
  }

  @Test func aBeanWithNoBrewsHasAnEmptySummary() throws {
    let harness = try Harness()
    let bean = try harness.bean("New")
    #expect(bean.bestSoFar.brewCount == 0)
    #expect(bean.bestSoFar.best == nil)
  }
}
