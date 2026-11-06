import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Bean brew advice AI")
struct BeanBrewAITests {
  @MainActor private struct Harness {
    let container: ModelContainer
    let store: Store
    let methods: [BrewMethod]
    let bean: Bean

    init() throws {
      container = try NextCupContainer.make(inMemory: true)
      let context = container.mainContext
      store = Store(context: context)
      let hidden = BrewMethod(name: "Siphon", style: .immersion)
      hidden.isHidden = true
      methods = [
        BrewMethod(name: "V60"), BrewMethod(name: "French Press", style: .immersion),
        BrewMethod(name: "AeroPress", style: .immersion), hidden,
      ]
      for (index, method) in methods.enumerated() {
        method.sortOrder = index
        context.insert(method)
      }
      let roaster = Roaster(name: "Onyx")
      bean = Bean(name: "Southern Weather")
      bean.roaster = roaster
      bean.roastLevel = .medium
      bean.process = "washed"
      bean.bagFlavorNotes = ["milk chocolate", "caramel"]
      context.insert(roaster)
      context.insert(bean)
      try context.save()
    }
  }

  private func pick(_ method: String, water: Double = 250) -> [String: Any] {
    [
      "method": method, "why": "Body.", "name": "Rich cup", "doseG": 16, "waterG": water,
      "tempC": 94, "totalTimeS": 240, "grind": "22",
      "steps": [
        ["kind": "pour", "atS": 0, "waterG": water, "instruction": "Pour it all."],
        ["kind": "wait", "atS": 30, "waterG": 0, "instruction": "Steep."],
      ],
    ]
  }

  @Test func payloadSendsBeanGoalBrewersAndNothingPrivate() throws {
    let rig = try Harness()
    let shown = BeanBrewAI.methods(store: rig.store)
    #expect(shown.map(\.name) == ["V60", "French Press", "AeroPress"])
    let text = BeanBrewAI.payload(
      bean: rig.bean, goal: " chocolatey and full-bodied ", methods: shown,
      grinder: "Baratza Encore"
    ).userText
    #expect(text.contains("Southern Weather from Onyx, medium roast"))
    #expect(text.contains("bag says milk chocolate, caramel"))
    #expect(text.contains("taste like: chocolatey and full-bodied"))
    #expect(text.contains("French Press (Immersion)"))
    #expect(text.contains("Grinder: Baratza Encore"))
    #expect(!text.contains("Siphon"))
    let none = BeanBrewAI.payload(bean: rig.bean, goal: "", methods: shown, grinder: nil).userText
    #expect(none.contains("no preference"))
  }

  @Test func parseKeepsThreeValidPicksOnKnownBrewersOnce() throws {
    let rig = try Harness()
    let answer: [String: Any] = [
      "summary": "Cocoa.",
      "picks": [
        pick("french press"), pick("Chemex"), pick("French Press"), pick("V60", water: 0),
        pick("V60"), pick("AeroPress"), pick("Siphon"),
      ],
    ]
    let outcome = try #require(
      BeanBrewAI.parse(
        answer, methods: rig.methods.filter { !$0.isHidden }, grinder: "Baratza Encore",
        bean: rig.bean, source: "Test"))
    #expect(outcome.picks.map(\.methodName) == ["French Press", "V60", "AeroPress"])
    let first = try #require(outcome.picks.first)
    #expect(first.draft.credit == BeanBrewAI.credit)
    #expect(first.draft.name == "Rich cup")
    #expect(first.draft.grindSetting == "22")
    #expect(first.draft.tuningNote?.contains("Grind: 22 on Baratza Encore.") == true)
    #expect(
      BeanBrewAI.parse(
        ["picks": []], methods: rig.methods, grinder: nil, bean: rig.bean, source: "") == nil)
  }

  @Test func savingTheSamePickAgainReplacesIt() throws {
    let rig = try Harness()
    let outcome = try #require(
      BeanBrewAI.parse(
        ["picks": [pick("V60")]], methods: rig.methods, grinder: nil, bean: rig.bean,
        source: "Test"))
    let draft = try #require(outcome.picks.first?.draft)
    let first = try BeanBrewAI.save(draft, store: rig.store).get()
    let second = try BeanBrewAI.save(draft, store: rig.store).get()
    #expect(first.id == second.id)
    let saved = try rig.container.mainContext.fetch(FetchDescriptor<Recipe>())
      .filter { $0.credit == BeanBrewAI.credit }
    #expect(saved.count == 1)
  }

  @Test func disclosureListsBrewAdvice() {
    let sends = AIFeature.diagnosis.sends
    #expect(
      sends.contains("brew advice on a bean") && sends.contains("what you want it to taste like"))
  }
}
