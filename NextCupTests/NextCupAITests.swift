import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Next Cup AI")
struct NextCupAITests {
  @MainActor private struct Harness {
    let container: ModelContainer
    let store: Store
    let method: BrewMethod
    let brew: Brew

    init() throws {
      container = try NextCupContainer.make(inMemory: true)
      let context = container.mainContext
      store = Store(context: context)
      method = BrewMethod(name: "Test Dripper")
      context.insert(method)
      let roaster = Roaster(name: "Onyx")
      let bean = Bean(name: "Geometry")
      bean.roaster = roaster
      bean.roastLevel = .light
      bean.originCountry = "Ethiopia"
      bean.bagFlavorNotes = ["peach"]
      let grinder = Grinder(name: "Baratza Encore")
      let part = BrewBean(grams: 18, beanNameSnapshot: "Geometry")
      part.bean = bean
      brew = Brew()
      brew.method = method
      brew.grinder = grinder
      brew.grindSetting = "18"
      brew.doseG = 18
      brew.waterG = 300
      brew.tempC = 93
      brew.totalTimeS = 180
      brew.ratingTenths = 65
      brew.verdict = .sour
      brew.alsoTasted = [Verdict.weak.rawValue]
      brew.notes = "Thin and sharp"
      brew.beans = [part]
      for model in [roaster, bean, grinder] as [any PersistentModel] { context.insert(model) }
      context.insert(brew)
      try context.save()
    }

    func recipes() throws -> [Recipe] {
      try container.mainContext.fetch(FetchDescriptor<Recipe>()).filter(\.isNextCup)
    }
  }

  private func answer(water: Double = 300, grind: String = "16") -> [String: Any] {
    [
      "summary": "Finer and hotter for more sweetness.",
      "changes": [["what": "Grind 18 to 16", "why": "Extracts more."]],
      "name": "Ignored", "doseG": 18, "waterG": 300, "tempC": 95, "totalTimeS": 200,
      "grind": grind,
      "steps": [
        ["kind": "bloom", "atS": 0, "waterG": 54, "instruction": "Bloom."],
        ["kind": "pour", "atS": 45, "waterG": water, "instruction": "Pour the rest."],
      ],
    ]
  }

  private func ask(_ harness: Harness, _ reply: [String: Any]) async throws -> NextCupAI.Outcome {
    try await NextCupAI.ask(
      about: harness.brew, store: harness.store, research: { _ in nil },
      send: { _ in (reply, "Anthropic") })
  }

  @Test func thePromptCarriesTheBrewTheBeanAndHowItTasted() throws {
    let harness = try Harness()
    let base = NextCupAI.base(for: harness.brew, store: harness.store)
    let text = NextCupAI.payload(for: harness.brew, base: base).userText
    for expected in [
      "Brewed: ", "Bean: Geometry from Onyx, light roast, Ethiopia, bag says peach",
      "Grind used: 18",
      "Rating: 6.5 out of 10", "Taste: sour, weak", "Their notes on this cup: Thin and sharp",
      "on a Test Dripper", "Dose: 18 g, total water: 300 g", "93 °C", "180 s",
      "Grinder: Baratza Encore", "Their other similar brews, newest first: none yet",
    ] {
      #expect(text.contains(expected), "\(expected) in \(text)")
    }
  }

  /// Another brew, by default with this one's method and amounts.
  @discardableResult private func other(
    _ harness: Harness, daysAgo: Int = 1, dose: Double? = 18, water: Double? = 300,
    method: BrewMethod? = nil, bean: Bean? = nil
  ) -> Brew {
    let brew = Brew(date: Date(timeIntervalSinceNow: Double(-daysAgo) * 86_400))
    brew.method = method ?? harness.method
    brew.doseG = dose
    brew.waterG = water
    if let bean {
      let part = BrewBean(grams: 18, beanNameSnapshot: bean.name)
      part.bean = bean
      brew.beans = [part]
    }
    harness.container.mainContext.insert(brew)
    return brew
  }

  @Test func similarBrewsAreSameMethodNotThisOneRankedByBeanThenAmountsThenDate() throws {
    let harness = try Harness()
    let bean = try #require(harness.brew.beans?.first?.bean)
    let otherMethod = BrewMethod(name: "Other Brewer")
    harness.container.mainContext.insert(otherMethod)
    let elsewhere = other(harness, daysAgo: 1, method: otherMethod, bean: bean)
    let far = other(harness, daysAgo: 1, dose: 40, water: 600)
    let nearOld = other(harness, daysAgo: 9, dose: 21, water: 250)
    let nearNew = other(harness, daysAgo: 2, dose: 18, water: 300)
    let unrecorded = other(harness, daysAgo: 3, dose: nil, water: 0)
    let halfFar = other(harness, daysAgo: 1, dose: 18, water: 400)
    let beanFarOld = other(harness, daysAgo: 30, dose: 40, water: 600, bean: bean)
    let beanFarNew = other(harness, daysAgo: 20, dose: 40, water: 600, bean: bean)
    let all = [
      harness.brew, elsewhere, far, nearOld, nearNew, unrecorded, halfFar, beanFarOld, beanFarNew,
    ]
    let expected = [beanFarNew, beanFarOld, nearNew, unrecorded, nearOld, far, halfFar]
    let found = NextCupAI.similarBrews(to: harness.brew, in: all, limit: 8)
    #expect(!found.contains { $0.id == harness.brew.id || $0.id == elsewhere.id })
    #expect(Array(found.prefix(5)).map(\.id) == Array(expected.prefix(5)).map(\.id))
    #expect(Set(found.suffix(2).map(\.id)) == Set([far.id, halfFar.id]))
    #expect(
      NextCupAI.similarBrews(to: harness.brew, in: all, limit: 3).map(\.id)
        == [beanFarNew, beanFarOld, nearNew].map(\.id))
  }

  @Test func aBrewWithNoMethodHasNoSimilarBrews() throws {
    let harness = try Harness()
    let loose = Brew()
    #expect(NextCupAI.similarBrews(to: loose, in: [harness.brew], limit: 8).isEmpty)
  }

  @Test func thePromptListsEachSimilarBrewOnOneLineWithAShortenedNote() throws {
    let harness = try Harness()
    let bean = try #require(harness.brew.beans?.first?.bean)
    let past = other(harness, bean: bean)
    past.recipe = Recipe(name: "Hoffmann", doseG: 15, waterG: 250)
    past.grinder = harness.brew.grinder
    past.grindSetting = "20"
    past.tempC = 94
    past.totalTimeS = 200
    past.ratingTenths = 82
    past.verdict = .balanced
    past.notes = "Line one\n" + String(repeating: "x", count: 300)
    let unrated = other(harness, daysAgo: 2)
    let base = NextCupAI.base(for: harness.brew, store: harness.store)
    let text = NextCupAI.payload(
      for: harness.brew, base: base, similar: [past, unrated], noteCharacters: 240
    ).userText
    let lines = text.components(separatedBy: "\n")
    let start = try #require(lines.firstIndex(of: "Their other similar brews, newest first:"))
    #expect(lines.count == start + 3, "one line a brew")
    let line = lines[start + 1]
    for expected in [
      past.date.formatted(date: .abbreviated, time: .omitted), "Hoffmann",
      "bean Geometry from Onyx, light roast", "dose 18 g", "water 300 g", "ratio 1:16.7",
      "grinder Baratza Encore at 20", "94 °C", "200 s", "taste balanced", "rated 8.2 out of 10",
      "notes: Line one xxx",
    ] {
      #expect(line.contains(expected), "\(expected) in \(line)")
    }
    #expect(line.hasSuffix("…"))
    #expect(!line.contains(String(repeating: "x", count: 240)), "the note stops at the limit")
    #expect(lines[start + 2].contains("not rated") && lines[start + 2].contains("taste not noted"))
  }

  @Test func askSendsHistoryWithTheProvidersLimitAndReportsTheCount() async throws {
    let harness = try Harness()
    for day in 1...6 { other(harness, daysAgo: day).notes = String(repeating: "y", count: 200) }
    try harness.container.mainContext.save()
    for (onDevice, count, full) in [(true, 4, false), (false, 6, true)] {
      var sent = ""
      let reply = answer()
      let outcome = try await NextCupAI.ask(
        about: harness.brew, store: harness.store, onDevice: onDevice, research: { _ in nil },
        send: { payload in
          sent = payload.userText
          return (reply, "Anthropic")
        })
      #expect(outcome.similarCount == count)
      #expect(sent.components(separatedBy: "\n- ").count - 1 == count)
      #expect(sent.contains(String(repeating: "y", count: 200)) == full)
    }
  }

  @Test func theSystemPromptAsksForAnOverviewReadingTheTrend() throws {
    let harness = try Harness()
    let system = NextCupAI.payload(
      for: harness.brew, base: NextCupAI.base(for: harness.brew, store: harness.store)
    ).system
    #expect(system.contains("3 to 6"))
    #expect(system.contains("as the trend"))
  }

  @Test func theRecipesStepsAreSentWithTheNumbersActuallyBrewed() throws {
    let harness = try Harness()
    let recipe = Recipe(name: "Hoffmann", doseG: 15, waterG: 250)
    recipe.steps = [RecipeStep(order: 0, kind: .pour, startOffsetS: 30)]
    harness.container.mainContext.insert(recipe)
    harness.brew.recipe = recipe
    let base = NextCupAI.base(for: harness.brew, store: harness.store)
    #expect(base.doseG == 18 && base.waterG == 300 && base.steps.count == 1)
    let text = NextCupAI.payload(for: harness.brew, base: base).userText
    #expect(text.contains("Recipe: Hoffmann") && text.contains("at 30 s, pour"))
  }

  @Test func theWebSearchNeverGetsTheBeanNameOrNotes() throws {
    let harness = try Harness()
    let question = try #require(
      NextCupAI.researchQuestion(for: harness.brew, grinder: "Baratza Encore"))
    #expect(question.contains("Test Dripper") && question.contains("light roast"))
    #expect(!question.contains("Geometry") && !question.contains("Thin and sharp"))
  }

  @Test func theAnswerIsSavedAsNextCupWithTheChangesAndGrind() async throws {
    let harness = try Harness()
    let outcome = try await ask(harness, answer())
    let recipe = try #require(harness.recipes().first)
    #expect(recipe.id == outcome.recipeID && outcome.replaced == nil)
    #expect(recipe.name == "Next Cup" && recipe.method?.id == harness.method.id)
    #expect(recipe.tempC == 95 && recipe.totalTimeS == 200 && recipe.orderedSteps.count == 2)
    #expect(recipe.grindSetting == "16" && recipe.grinderName == "Baratza Encore")
    let note = try #require(recipe.tuningNote)
    #expect(note.contains("From your Geometry brew") && note.contains("rated 6.5"))
    #expect(note.contains("AI changes:\n• Grind 18 to 16: Extracts more."))
    #expect(note.hasSuffix("Grind: 16 on Baratza Encore."))
  }

  @Test func noGrindFromTheAIKeepsTheBrews() async throws {
    let harness = try Harness()
    _ = try await ask(harness, answer(grind: ""))
    #expect(try harness.recipes().first?.grindSetting == "18")
  }

  @Test func anAnswerThatDoesNotAddUpIsDroppedAndChangesNothing() async throws {
    let harness = try Harness()
    await #expect(throws: AIError.invalidResponse) {
      // The last pour stops 100 g short of the recipe's water.
      _ = try await ask(harness, answer(water: 200))
    }
    #expect(try harness.recipes().isEmpty)
    #expect(NextCupAIView.message(for: AIError.invalidResponse).contains("nothing was changed"))
  }

  @Test func askingAgainReplacesThatMethodsNextCupAndCanBePutBack() async throws {
    let harness = try Harness()
    let first = try await ask(harness, answer(grind: "16"))
    let second = try await ask(harness, answer(grind: "14"))
    #expect(try harness.recipes().count == 1 && first.recipeID == second.recipeID)
    let recipe = try #require(harness.recipes().first)
    #expect(recipe.grindSetting == "14" && recipe.orderedSteps.count == 2)
    let old = try #require(second.replaced)
    _ = RecipeEditorService(store: harness.store).save(old)
    #expect(recipe.grindSetting == "16" && recipe.isNextCup)
  }

  @Test func eachMethodKeepsItsOwnAndAUsersOwnRecipeIsLeftAlone() async throws {
    let harness = try Harness()
    let context = harness.container.mainContext
    let mine = Recipe(name: "Next Cup", doseG: 10, waterG: 160)
    mine.method = harness.method
    context.insert(mine)
    _ = try await ask(harness, answer())
    #expect(mine.doseG == 10 && !mine.isNextCup, "hand-named recipe untouched")

    let other = BrewMethod(name: "Other Brewer")
    context.insert(other)
    harness.brew.method = other
    _ = try await ask(harness, answer())
    #expect(try harness.recipes().count == 2)
  }

  @Test func renamedItIsTheUsersAndTheNextAskMakesANewOne() async throws {
    let harness = try Harness()
    let first = try await ask(harness, answer())
    try #require(harness.recipes().first).name = "Keeper"
    let second = try await ask(harness, answer())
    #expect(first.recipeID != second.recipeID && second.replaced == nil)
  }

  @Test func theDisclosureListsWhatThisSends() {
    let sends = AIFeature.diagnosis.sends
    #expect(sends.contains("Ask AI for Next Cup") && sends.contains("bean name, roaster, roast"))
    #expect(sends.contains("up to \(NextCupAI.cloudHistory.brews) of your other brews"))
    #expect(!sends.contains("Ask AI about this brew"))
  }
}
