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

  /// Apple's small model answers with nonsense amounts (12 g of water): the brewer's
  /// built-in recipe stands in, keeping the AI's name, temperature and grind.
  @Test func anUnsoundRecipeFallsBackToTheBrewersBuiltInOne() throws {
    let rig = try Harness()
    var builtIn = RecipeDraft()
    builtIn.name = "Classic"
    builtIn.doseG = 15
    builtIn.waterG = 250
    builtIn.tempC = 94
    builtIn.steps = [RecipeStepDraft(kind: .pour, startOffsetS: 0, targetCumulativeWaterG: 250)]
    var tiny = pick("V60", water: 12)
    tiny["tempC"] = 91
    let outcome = try #require(
      BeanBrewAI.parse(
        ["picks": [tiny, pick("AeroPress", water: 30)]], methods: rig.methods, grinder: nil,
        bean: rig.bean, source: "Test",
        fallback: { $0.name == "V60" ? builtIn : nil }))
    #expect(outcome.picks.map(\.methodName) == ["V60"], "AeroPress has no built-in to fall back on")
    let draft = try #require(outcome.picks.first?.draft)
    #expect(draft.waterG == 250 && draft.doseG == 15)
    #expect(draft.name == "Rich cup" && draft.tempC == 91)
    #expect(draft.credit == BeanBrewAI.credit && draft.methodID == rig.methods[0].id)
  }

  /// The small model repeats a brewer: the spare slot is a built-in recipe of another
  /// brewer, the same style as the picks first, so there are always three.
  @Test func aRepeatedBrewerIsToppedUpFromAnotherBuiltIn() throws {
    let rig = try Harness()
    var builtIn = RecipeDraft()
    builtIn.name = "House"
    builtIn.doseG = 15
    builtIn.waterG = 240
    builtIn.steps = [RecipeStepDraft(kind: .pour, startOffsetS: 0, targetCumulativeWaterG: 240)]
    let answer: [String: Any] = [
      "summary": "", "first": pick("French Press"), "second": pick("French Press"),
      "third": pick("V60"),
    ]
    let outcome = try #require(
      BeanBrewAI.parse(
        answer, methods: rig.methods.filter { !$0.isHidden }, grinder: nil, bean: rig.bean,
        source: "Test", fallback: { _ in builtIn }))
    #expect(outcome.picks.map(\.methodName) == ["French Press", "V60", "AeroPress"])
    #expect(outcome.picks[2].draft.name == "House" && outcome.picks[2].why.isEmpty)
    #expect(outcome.picks[2].draft.credit == BeanBrewAI.credit)
  }

  @Test func soundRatiosDependOnTheBrewer() {
    var draft = RecipeDraft()
    draft.doseG = 18
    draft.waterG = 36
    #expect(BeanBrewAI.isSound(draft, style: .espresso))
    #expect(!BeanBrewAI.isSound(draft, style: .pourOver))
    draft.waterG = 288
    #expect(!BeanBrewAI.isSound(draft, style: .pourOver), "no steps or time")
    draft.totalTimeS = 210
    draft.steps = [
      RecipeStepDraft(kind: .bloom, startOffsetS: 0, targetCumulativeWaterG: 50),
      RecipeStepDraft(kind: .pour, startOffsetS: 45, targetCumulativeWaterG: 288),
    ]
    #expect(BeanBrewAI.isSound(draft, style: .pourOver))
    #expect(!BeanBrewAI.isSound(draft, style: .espresso))
  }

  @Test func savedPickWaitsToTryAndSavingAgainReplacesIt() throws {
    let rig = try Harness()
    let outcome = try #require(
      BeanBrewAI.parse(
        ["picks": [pick("V60")]], methods: rig.methods, grinder: nil, bean: rig.bean,
        source: "Test"))
    let draft = try #require(outcome.picks.first?.draft)
    let first = try BeanBrewAI.save(draft, store: rig.store).get()
    let second = try BeanBrewAI.save(draft, store: rig.store).get()
    #expect(first.id == second.id && first.isToTry && !first.isNextCup)
    #expect(first.tuningNote?.contains("Southern Weather") == true)
    let brew = Brew()
    rig.container.mainContext.insert(brew)
    brew.recipe = first
    try rig.container.mainContext.save()
    #expect(!first.isToTry, "a brewed pick joins the user's recipes")
  }

  @Test func eachTasteGetsOneRecipe() async throws {
    let rig = try Harness()
    let goals = ["Chocolatey and full-bodied", " ", "Bright and fruity"]
    let text = BeanBrewAI.payload(bean: rig.bean, goals: goals, methods: rig.methods, grinder: nil)
      .userText
    #expect(
      text.contains("first: Chocolatey and full-bodied; second: Bright and fruity"))
    let outcome = try await BeanBrewAI.ask(
      bean: rig.bean, goals: goals, store: rig.store, grinder: nil,
      send: { _ in (["picks": [pick("V60"), pick("French Press"), pick("AeroPress")]], "Test") })
    #expect(outcome.picks.map(\.goal) == ["Chocolatey and full-bodied", "Bright and fruity"])
  }

  @Test func disclosureListsBrewAdvice() {
    let sends = AIFeature.diagnosis.sends
    #expect(
      sends.contains("brew advice on a bean") && sends.contains("what you want it to taste like"))
  }
}
