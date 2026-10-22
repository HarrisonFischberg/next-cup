import Foundation
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Methods")
struct MethodsServiceTests {
  /// Holds the container so the context stays valid for the whole test.
  @MainActor
  private struct Harness {
    let container: ModelContainer
    let service: MethodsService

    init(methods: [String] = ["Alpha", "Beta", "Gamma"]) throws {
      container = try NextCupContainer.make(inMemory: true)
      let store = Store(context: container.mainContext)
      service = MethodsService(store: store)
      for (index, name) in methods.enumerated() {
        let method = BrewMethod(name: name)
        method.sortOrder = index
        method.trackedParameters = [.dose, .water, .grind]
        container.mainContext.insert(method)
      }
      try container.mainContext.save()
    }

    var names: [String] { service.all().map(\.name) }
  }

  private func failure<T>(_ result: Result<T, MethodsError>) -> MethodsError? {
    if case .failure(let error) = result { return error }
    return nil
  }

  @Test func addAppendsAfterTheLastMethodWithTheChosenFields() throws {
    let harness = try Harness()
    let added = try harness.service.add(
      name: "  Moka pot  ", style: .espresso, chosen: [.time, .notes]
    ).get()
    #expect(added.name == "Moka pot")
    #expect(added.style == .espresso)
    #expect(added.sortOrder == 3)
    #expect(Set(added.trackedParameters) == [.dose, .water, .time, .notes])
    #expect(harness.names == ["Alpha", "Beta", "Gamma", "Moka pot"])
  }

  @Test func rejectsAnEmptyOrDuplicateName() throws {
    let harness = try Harness()
    #expect(failure(harness.service.add(name: "   ", style: .pourOver, chosen: [])) == .emptyName)
    #expect(
      failure(harness.service.add(name: "alpha", style: .pourOver, chosen: []))
        == .duplicateName)
    #expect(harness.names.count == 3)
  }

  @Test func renameKeepsIdentityAndAllowsItsOwnNameInAnotherCase() throws {
    let harness = try Harness()
    let beta = try #require(harness.service.all().first { $0.name == "Beta" })
    let id = beta.id
    try harness.service.update(beta, name: "BETA", chosen: [.grind]).get()
    #expect(beta.id == id)
    #expect(beta.name == "BETA")
    #expect(failure(harness.service.update(beta, name: "Gamma", chosen: [])) == .duplicateName)
  }

  @Test func updateKeepsYieldAndTDSTheEditorDoesNotOffer() throws {
    let harness = try Harness()
    let method = try #require(harness.service.all().first)
    method.trackedParameters = [.dose, .yield, .tds, .grind, .photo]
    try harness.service.update(method, name: method.name, chosen: [.time]).get()
    #expect(Set(method.trackedParameters) == [.dose, .water, .yield, .tds, .time])
  }

  @Test func dragMoveRenumbersWithoutGaps() throws {
    let harness = try Harness()
    try harness.service.move(from: IndexSet(integer: 2), to: 0).get()
    #expect(harness.names == ["Gamma", "Alpha", "Beta"])
    #expect(harness.service.all().map(\.sortOrder) == [0, 1, 2])
  }

  @Test func moveUpAndDownWithoutGesture() throws {
    let harness = try Harness()
    let beta = try #require(harness.service.all().first { $0.name == "Beta" })
    try harness.service.step(beta, by: -1).get()
    #expect(harness.names == ["Beta", "Alpha", "Gamma"])
    // The top cannot go higher and nothing changes.
    try harness.service.step(beta, by: -1).get()
    #expect(harness.names == ["Beta", "Alpha", "Gamma"])
    try harness.service.step(beta, by: 1).get()
    try harness.service.step(beta, by: 1).get()
    #expect(harness.names == ["Alpha", "Gamma", "Beta"])
  }

  @Test func hidingKeepsTheMethodItsBrewsAndItsPlace() throws {
    let harness = try Harness()
    let context = harness.container.mainContext
    let beta = try #require(harness.service.all().first { $0.name == "Beta" })
    let brew = Brew()
    brew.method = beta
    context.insert(brew)
    try context.save()

    try harness.service.setHidden(beta, true).get()
    #expect(beta.isHidden)
    #expect(harness.names == ["Alpha", "Beta", "Gamma"])
    #expect(brew.method?.id == beta.id, "history keeps its method")
    try harness.service.setHidden(beta, false).get()
    #expect(!beta.isHidden)
  }

  @Test func formShowsExactlyTheEnabledParametersPlusDoseAndWater() {
    #expect(MethodParameters.shown(tracked: []) == [.dose, .water])
    #expect(
      MethodParameters.shown(tracked: [.grind, .rating, .temperature])
        == [.dose, .water, .grind, .rating, .temperature])
    #expect(
      MethodParameters.shown(tracked: BrewParameter.allCases) == Set(BrewParameter.allCases))
  }

  @Test func everyBuiltInMethodStillShowsTheFieldsItDidBefore() throws {
    let methods = try BuiltInContent(bundle: .main).methods
    #expect(!methods.isEmpty)
    for method in methods {
      let shown = MethodParameters.shown(tracked: method.trackedParameters)
      #expect(shown.isSuperset(of: [.dose, .water]), "\(method.name) shows dose and water")
      #expect(shown.contains(.grind) && shown.contains(.time), "\(method.name) keeps grind, time")
    }
  }
}
