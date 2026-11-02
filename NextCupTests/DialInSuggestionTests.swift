import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Dial-in suggestions")
struct DialInSuggestionTests {
  @MainActor
  private struct Harness {
    let container: ModelContainer
    let store: Store
    let beans: BeanService
    let draftStore: DraftStore
    let defaults: UserDefaults
    let method: BrewMethod
    var context: ModelContext { container.mainContext }
    var service: SuggestionService { SuggestionService(store: store) }
    var units: UnitPreferences { UnitPreferences(weight: .grams, temperature: .celsius) }

    init() throws {
      container = try NextCupContainer.make(inMemory: true)
      store = Store(context: container.mainContext)
      beans = BeanService(store: store)
      draftStore = DraftStore(
        fileURL: FileManager.default.temporaryDirectory
          .appendingPathComponent("nextcup-dialin-\(UUID().uuidString)/brew-draft.json"))
      defaults = UserDefaults(suiteName: "nextcup.dialintests.\(UUID().uuidString)") ?? .standard
      method = BrewMethod(name: "V60", style: .pourOver)
      method.trackedParameters = [.dose, .water, .grind, .temperature, .time]
      container.mainContext.insert(method)
    }

    func bean(_ name: String) throws -> Bean {
      var fields = BeanFields()
      fields.name = name
      fields.bagWeightG = 250
      return try beans.save(fields).get()
    }

    func model(repeating: Brew? = nil) -> BrewFormModel {
      BrewFormModel(
        seed: nil, repeating: repeating, store: store, draftStore: draftStore, defaults: defaults)
    }

    /// Logs a brew through the real form model and returns the saved brew.
    @discardableResult
    func log(
      _ verdict: Verdict?, also: [Verdict] = [], bean: Bean? = nil, grind: String = "20",
      daysAgo: Int = 0
    ) throws -> Brew {
      let model = model()
      model.draft.methodID = method.id
      model.draft.doseG = 15
      model.draft.waterG = 250
      model.draft.tempC = 94
      model.draft.grindSetting = grind
      model.draft.verdict = Verdict.joined((verdict.map { [$0] } ?? []) + also)
      model.draft.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
      if let bean { model.addBean(bean) }
      #expect(model.save())
      return try #require(
        try context.fetch(FetchDescriptor<Brew>()).first { $0.id == model.draft.id })
    }

    func suggestions() throws -> [Suggestion] { try context.fetch(FetchDescriptor<Suggestion>()) }
  }

  // MARK: Rules to rows

  @Test func aSourCupStoresAFinerGrindLinkedToItsBrew() throws {
    let harness = try Harness()
    let brew = try harness.log(.sour)
    let stored = try #require(try harness.suggestions().first)
    #expect(stored.source == .rules)
    #expect(stored.field == .grind)
    #expect(stored.fromValue == "20")
    #expect(stored.toValue == "19")
    #expect(stored.state == .proposed)
    #expect(stored.sourceBrew?.id == brew.id)
    #expect(!stored.rationale.isEmpty)
  }

  @Test func eachVerdictMakesWhatTheRulesSay() throws {
    let expected: [(Verdict, BrewParameter?, String?)] = [
      (.sour, .grind, "19"), (.bitter, .grind, "21"), (.weak, .water, "235"),
      (.strong, .water, "270"), (.balanced, nil, nil), (.bright, nil, nil),
    ]
    for (verdict, field, value) in expected {
      let harness = try Harness()
      try harness.log(verdict)
      let stored = try harness.suggestions()
      #expect(stored.first?.field == field)
      #expect(stored.first?.toValue == value)
      #expect(stored.count == (field == nil ? 0 : 1))
    }
  }

  @Test func aFaultPickedWithBalancedDecidesTheChange() throws {
    let harness = try Harness()
    try harness.log(.balanced, also: [.sour])
    #expect(try harness.suggestions().first?.toValue == "19")
  }

  @Test func aFaultPickedWithBrightDecidesTheChange() throws {
    let harness = try Harness()
    try harness.log(.bright, also: [.sour])
    #expect(try harness.suggestions().first?.toValue == "19")
  }

  @Test func noVerdictMakesNoSuggestion() throws {
    let harness = try Harness()
    try harness.log(nil)
    #expect(try harness.suggestions().isEmpty)
  }

  @Test func theSavedFormExplainsWhyThereIsNoChange() throws {
    let harness = try Harness()
    let model = harness.model()
    model.draft.methodID = harness.method.id
    model.draft.doseG = 15
    model.draft.waterG = 250
    model.draft.verdict = Verdict.balanced.rawValue
    #expect(model.save())
    #expect(model.madeSuggestion == nil)
    #expect(model.dialInNote?.contains("balanced") == true)
  }

  @Test func editingTheVerdictReplacesAnUnansweredSuggestion() throws {
    let harness = try Harness()
    let brew = try harness.log(.sour)
    let edit = BrewFormModel(
      seed: nil, editing: brew, store: harness.store, draftStore: harness.draftStore,
      defaults: harness.defaults)
    edit.draft.verdict = Verdict.bitter.rawValue
    #expect(edit.save())
    let stored = try harness.suggestions()
    #expect(stored.count == 1)
    #expect(stored.first?.toValue == "21")
  }

  @Test func editingABrewNeverRewritesAnAnsweredSuggestion() throws {
    let harness = try Harness()
    let brew = try harness.log(.sour)
    let suggestion = try #require(try harness.suggestions().first)
    suggestion.state = .dismissed
    let edit = BrewFormModel(
      seed: nil, editing: brew, store: harness.store, draftStore: harness.draftStore,
      defaults: harness.defaults)
    edit.draft.verdict = Verdict.bitter.rawValue
    #expect(edit.save())
    let stored = try harness.suggestions()
    #expect(stored.count == 1)
    #expect(stored.first?.toValue == "19")
    #expect(stored.first?.state == .dismissed)
  }

  @Test func deletingTheBrewDeletesItsSuggestion() throws {
    let harness = try Harness()
    let brew = try harness.log(.sour)
    harness.context.delete(brew)
    if case .failure = harness.store.save() { Issue.record("delete did not save") }
    #expect(try harness.suggestions().isEmpty)
  }

  // MARK: Next brew of that bean

  @Test func theSuggestionIsFoundOnTheNextBrewOfThatBeanOnly() throws {
    let harness = try Harness()
    let ethiopia = try harness.bean("Ethiopia")
    let brazil = try harness.bean("Brazil")
    let brew = try harness.log(.sour, bean: ethiopia)
    let all = try harness.suggestions()

    let match = SuggestionService.match(
      in: all, beanIDs: [ethiopia.id], methodID: harness.method.id, excluding: UUID())
    #expect(match?.sourceBrew?.id == brew.id)
    #expect(
      SuggestionService.match(
        in: all, beanIDs: [brazil.id], methodID: harness.method.id, excluding: UUID()) == nil)
    #expect(
      SuggestionService.match(
        in: all, beanIDs: [ethiopia.id], methodID: harness.method.id, excluding: brew.id) == nil)
    #expect(
      SuggestionService.match(in: all, beanIDs: [], methodID: harness.method.id, excluding: UUID())
        == nil)
  }

  @Test func brewsWithNoBeansMatchOnMethod() throws {
    let harness = try Harness()
    try harness.log(.bitter)
    let all = try harness.suggestions()
    #expect(
      SuggestionService.match(in: all, beanIDs: [], methodID: harness.method.id, excluding: UUID())
        != nil)
    #expect(
      SuggestionService.match(in: all, beanIDs: [], methodID: UUID(), excluding: UUID()) == nil)
  }

  @Test func aNewerBrewOfTheSameBeanSupersedesTheOlderSuggestion() throws {
    let harness = try Harness()
    let bean = try harness.bean("Kenya")
    try harness.log(.sour, bean: bean, daysAgo: 2)
    try harness.log(.bitter, bean: bean, daysAgo: 0)
    let all = try harness.suggestions().sorted { $0.createdAt < $1.createdAt }
    #expect(all.map(\.state) == [.dismissed, .proposed])
    let match = SuggestionService.match(
      in: all, beanIDs: [bean.id], methodID: harness.method.id, excluding: UUID())
    #expect(match?.toValue == "21")
  }

  // MARK: Answering

  @Test func acceptingAppliesTheChangeAndLinksTheNextBrew() throws {
    let harness = try Harness()
    let bean = try harness.bean("Kenya")
    try harness.log(.sour, bean: bean)
    let suggestion = try #require(try harness.suggestions().first)

    let next = harness.model()
    next.draft.methodID = harness.method.id
    next.draft.doseG = 15
    next.draft.waterG = 250
    next.draft.grindSetting = "20"
    next.addBean(bean)
    next.applySuggestion(suggestion)
    #expect(next.draft.grindSetting == "19")
    #expect(suggestion.state == .accepted)
    #expect(next.handledSuggestionID == suggestion.id)

    #expect(next.save())
    let saved = try #require(
      try harness.context.fetch(FetchDescriptor<Brew>()).first { $0.id == next.draft.id })
    #expect(saved.suggestionFollowed?.id == suggestion.id)
    #expect(suggestion.appliedTo?.count == 1)
  }

  @Test func editingTheValueAppliesTheUsersNumber() throws {
    let harness = try Harness()
    try harness.log(.sour)
    let suggestion = try #require(try harness.suggestions().first)
    let next = harness.model()
    next.draft.grindSetting = "20"
    next.applySuggestion(suggestion, editedTo: "17")
    #expect(next.draft.grindSetting == "17")
    #expect(suggestion.state == .edited)
    #expect(suggestion.toValue == "17")
  }

  @Test func anUnusableEditChangesNothing() throws {
    let harness = try Harness()
    try harness.log(.weak)
    let suggestion = try #require(try harness.suggestions().first)
    let next = harness.model()
    next.draft.waterG = 250
    next.applySuggestion(suggestion, editedTo: "lots")
    #expect(next.draft.waterG == 250)
    #expect(suggestion.state == .proposed)
    #expect(next.suggestionError != nil)
    next.applySuggestion(suggestion, editedTo: "")
    #expect(suggestion.state == .proposed)
  }

  @Test func undoRestoresTheValueAndTheCardWaitsAgain() throws {
    let harness = try Harness()
    try harness.log(.weak)
    let suggestion = try #require(try harness.suggestions().first)
    let next = harness.model()
    next.draft.doseG = 15
    next.draft.waterG = 250
    next.applySuggestion(suggestion, editedTo: "230")
    #expect(next.draft.waterG == 230)
    next.undoSuggestionAnswer(suggestion)
    #expect(next.draft.waterG == 250)
    #expect(suggestion.state == .proposed)
    #expect(suggestion.toValue == "235")
    #expect(next.handledSuggestionID == nil)
    #expect(next.save())
    let saved = try #require(
      try harness.context.fetch(FetchDescriptor<Brew>()).first { $0.id == next.draft.id })
    #expect(saved.suggestionFollowed == nil)
  }

  @Test func dismissingKeepsTheDraftAndCanBeTakenBack() throws {
    let harness = try Harness()
    try harness.log(.bitter)
    let suggestion = try #require(try harness.suggestions().first)
    let next = harness.model()
    next.draft.grindSetting = "20"
    next.dismissSuggestion(suggestion)
    #expect(next.draft.grindSetting == "20")
    #expect(suggestion.state == .dismissed)
    #expect(
      SuggestionService.match(
        in: [suggestion], beanIDs: [], methodID: harness.method.id, excluding: UUID()) == nil)
    next.undoSuggestionAnswer(suggestion)
    #expect(suggestion.state == .proposed)
    #expect(next.draft.grindSetting == "20")
  }

  // MARK: Display

  @Test func valuesShowInTheUsersUnits() throws {
    let ounces = UnitPreferences(weight: .ounces, temperature: .fahrenheit)
    let grams = UnitPreferences(weight: .grams, temperature: .celsius)
    #expect(SuggestionFormat.display("250", for: .water, grams) == "250 g")
    #expect(SuggestionFormat.display("94", for: .temperature, ounces) == "201°F")
    #expect(SuggestionFormat.display("185", for: .time, grams) == "3:05")
    #expect(SuggestionFormat.display("", for: .grind, grams) == "not set")
    #expect(SuggestionFormat.canonical("201", for: .temperature, ounces) == "94")
    #expect(SuggestionFormat.canonical("8.82", for: .water, ounces) == "250")
    #expect(SuggestionFormat.canonical("  ", for: .grind, grams) == nil)
    #expect(SuggestionFormat.canonical("abc", for: .time, grams) == nil)
  }

  @Test func theHeadlineNamesTheFieldAndBothValues() throws {
    let harness = try Harness()
    try harness.log(.sour)
    let suggestion = try #require(try harness.suggestions().first)
    #expect(SuggestionFormat.headline(suggestion, harness.units) == "Grind: 20 → 19")
    #expect(SuggestionFormat.spoken(suggestion, harness.units) == "Grind from 20 to 19")
  }
}
