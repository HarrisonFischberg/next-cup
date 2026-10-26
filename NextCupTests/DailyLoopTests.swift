import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Daily loop")
struct DailyLoopTests {
  private let container: ModelContainer
  private let store: Store
  private let method: BrewMethod
  private let defaults = UserDefaults(suiteName: "nextcup.dailyloop.\(UUID().uuidString)")!

  init() throws {
    container = try NextCupContainer.make(inMemory: true)
    store = Store(context: container.mainContext)
    method = BrewMethod(name: "V60", style: .pourOver)
    method.trackedParameters = [.dose, .water, .grind, .temperature, .time]
    container.mainContext.insert(method)
  }

  private func model() -> BrewFormModel {
    BrewFormModel(
      seed: nil, repeating: nil, store: store,
      draftStore: DraftStore(
        fileURL: FileManager.default.temporaryDirectory
          .appendingPathComponent("nextcup-loop-\(UUID().uuidString)/brew-draft.json")),
      defaults: defaults)
  }

  private func bean(_ name: String) throws -> Bean {
    var fields = BeanFields()
    fields.name = name
    fields.bagWeightG = 250
    return try BeanService(store: store).save(fields).get()
  }

  @discardableResult
  private func log(
    _ verdict: Verdict?, bean: Bean? = nil, grind: String = "20", daysAgo: Int = 0
  ) throws -> Brew {
    let model = model()
    model.draft.methodID = method.id
    model.draft.doseG = 15
    model.draft.waterG = 250
    model.draft.grindSetting = grind
    model.draft.verdict = verdict?.rawValue
    model.draft.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    if let bean { model.addBean(bean) }
    #expect(model.save())
    return try #require(
      try container.mainContext.fetch(FetchDescriptor<Brew>()).first { $0.id == model.draft.id })
  }

  // MARK: Taste link

  @Test func tasteLinkRoundTripsToTheJournal() {
    let id = UUID()
    let link = DeepLink.taste(id)
    #expect(DeepLink(url: link.url) == link)
    #expect(link.url.absoluteString == "nextcup://taste/\(id.uuidString)")
    #expect(link.tab == .journal)
    #expect(DeepLink(url: URL(string: "nextcup://taste/not-a-uuid")!) == nil)
  }

  @Test func theReminderIsDueTwentyMinutesAfterBrewing() {
    let brewed = Date(timeIntervalSince1970: 1_000_000)
    #expect(TasteReminder.due(after: brewed).timeIntervalSince(brewed) == 20 * 60)
  }

  // MARK: Today card

  @Test func todaysUntastedCupIsInTheLoop() throws {
    #expect(TodayCard.applies(to: try log(nil)))
  }

  @Test func anEarlierDaysCupIsNot() throws {
    #expect(!TodayCard.applies(to: try log(nil, daysAgo: 1)))
  }

  @Test func aBalancedCupLeavesTheLoop() throws {
    #expect(!TodayCard.applies(to: try log(.balanced)))
  }

  @Test func aSourCupStaysWithItsChangeForTomorrow() throws {
    let brew = try log(.sour)
    #expect((brew.suggestionsMade ?? []).contains { $0.state == .proposed })
    #expect(TodayCard.applies(to: brew))
  }

  // MARK: Grind per bean

  @Test func aBeanBringsBackItsLastGrindAndGrinder() throws {
    let kenya = try bean("Kenya Kiambu AA")
    let first = model()
    first.draft.methodID = method.id
    first.draft.doseG = 15
    first.draft.waterG = 250
    #expect(first.addGrinder(named: "Comandante C40 MK4"))
    first.draft.grindSetting = "22"
    first.addBean(kenya)
    #expect(first.save())

    let next = model()
    next.setGrinder(nil)
    next.addBean(kenya)
    #expect(next.draft.grindSetting == "22")
    #expect(next.draft.grinderID == first.draft.grinderID)
  }

  @Test func aGrindAlreadyTypedIsKept() throws {
    let kenya = try bean("Kenya Kiambu AA")
    try log(.sour, bean: kenya, grind: "22")
    let next = model()
    next.draft.grindSetting = "25"
    next.addBean(kenya)
    #expect(next.draft.grindSetting == "25")
  }
}
