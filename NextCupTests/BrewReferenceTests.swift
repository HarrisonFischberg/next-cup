import Foundation
import NextCupKit
import Testing

@testable import NextCup

@MainActor
@Suite("Brew reference")
struct BrewReferenceTests {
  private func draft(
    dose: Double, water: Double, temp: Double? = 94, time: Int? = 180
  ) -> RecipeDraft {
    var draft = RecipeDraft()
    draft.doseG = dose
    draft.waterG = water
    draft.tempC = temp
    draft.totalTimeS = time
    draft.steps = [
      RecipeStepDraft(kind: .bloom, startOffsetS: 0, targetCumulativeWaterG: dose * 3),
      RecipeStepDraft(kind: .pour, startOffsetS: 45, targetCumulativeWaterG: water),
    ]
    return draft
  }

  private var cone: BrewReference { BrewReference.methods["cone-dripper"]! }

  /// The limits only catch mistakes: nothing the app ships is one.
  @Test func everyBuiltInRecipePassesItsBrewersLimits() throws {
    let content = try BuiltInContent()
    for entry in content.recipes {
      let style = content.methods.first { $0.key == entry.methodKey }?.style
      guard let reference = BrewReference.find(methodKey: entry.methodKey, style: style) else {
        continue
      }
      var draft = RecipeDraft()
      draft.doseG = entry.doseG
      draft.waterG = entry.waterG
      draft.tempC = entry.tempC
      draft.totalTimeS = entry.totalTimeS
      draft.includesIce = entry.includesIce
      draft.iceG = entry.iceG
      #expect(reference.problem(draft) == nil, "\(entry.key): \(reference.problem(draft) ?? "")")
    }
  }

  @Test func everyBuiltInBrewerButNespressoHasAReference() throws {
    for method in try BuiltInContent().methods where method.key != "nespresso" {
      #expect(BrewReference.methods[method.key] != nil, "\(method.key)")
    }
    #expect(BrewReference.find(methodKey: "nespresso", style: .espresso) == nil)
    #expect(BrewReference.find(methodKey: nil, style: .pourOver) != nil, "a brewer the user made")
    #expect(BrewReference.find(methodKey: nil, style: nil) == nil)
  }

  @Test func numbersNoRecipeUsesAreNamed() throws {
    #expect(cone.problem(draft(dose: 15, water: 250)) == nil)
    let thin = try #require(cone.problem(draft(dose: 10, water: 400)))
    #expect(thin.contains("1:40") && thin.contains("1:13 to 1:19"))
    let cold = try #require(cone.problem(draft(dose: 15, water: 250, temp: 40)))
    #expect(cold.contains("40 °C") && cold.contains("80 and 100 °C"))
    let quick = try #require(cone.problem(draft(dose: 15, water: 250, time: 20)))
    #expect(quick.contains("0:20") && quick.contains("1:45 and 6:00"))
    #expect(cone.problem(draft(dose: 15, water: 250, temp: nil, time: nil)) == nil)
  }

  @Test func iceCountsTowardTheRatio() {
    var iced = draft(dose: 20, water: 200)
    #expect(cone.problem(iced) != nil, "1:10 with no ice is too strong for a cone")
    iced.includesIce = true
    iced.iceG = 120
    #expect(cone.problem(iced) == nil)
  }

  /// Someone who brews 1:11 on purpose is not told their own recipe is wrong.
  @Test func theUsersOwnNumbersAreNeverTheMistake() {
    let theirs = draft(dose: 20, water: 220, temp: 78)
    #expect(cone.problem(theirs) != nil)
    #expect(cone.problem(theirs, from: theirs) == nil, "unchanged")
    #expect(cone.problem(draft(dose: 20, water: 240, temp: 80), from: theirs) == nil, "closer")
    #expect(cone.problem(draft(dose: 20, water: 200, temp: 78), from: theirs) != nil, "further")
  }

  @Test func aNextCupOnlyMovesALittle() throws {
    let cup = draft(dose: 15, water: 250, temp: 92)
    #expect(cone.problem(draft(dose: 16, water: 250, temp: 95), from: cup, smallSteps: true) == nil)
    let far = try #require(
      cone.problem(draft(dose: 22, water: 380, temp: 99), from: cup, smallSteps: true))
    #expect(far.contains("coffee from 15 g to 22 g") && far.contains("water from 250 g to 380 g"))
    #expect(far.contains("temperature from 92 to 99 °C"))
    #expect(cone.problem(draft(dose: 22, water: 380, temp: 99), from: cup) == nil, "a note may")
  }

  @Test func thePromptGivesTheUsualNumbersAndTheRoastsTemperature() {
    let line = cone.promptLine()
    #expect(line.contains("1:15 to 1:17") && line.contains("never outside 1:13 to 1:19"))
    #expect(line.contains("90 to 96 °C (hotter for light roasts, cooler for dark)"))
    #expect(line.contains("2:30 to 3:30") && line.contains("Bloom with 2 to 3 times"))
    #expect(cone.promptLine(roast: .light).contains("about 96 °C for this roast"))
    #expect(cone.promptLine(roast: .dark).contains("about 90 °C for this roast"))
    let cold = BrewReference.methods["cold-brew"]!
    #expect(!cold.promptLine().contains("°C") && cold.promptLine().contains("12 h to 18 h"))
    #expect(cone.shortLine == "usually 1:15 to 1:17, 90 to 96 °C, 2:30 to 3:30")
  }

  @Test func thePromptLineGoesIntoEveryRecipeRequest() {
    let line = cone.promptLine()
    let improve = RecipeReviewAI.payload(
      draft(dose: 15, water: 250), methodName: "V60", note: "", reference: line)
    #expect(improve.userText.contains(line))
    let create = RecipeReviewAI.createPayload(
      methodName: "V60", style: "Pour over", note: "one cup", reference: line)
    #expect(create.userText.contains(line))
  }

  // MARK: Asking again

  private func answer(dose: Double, water: Double) -> [String: Any] {
    [
      "summary": "Second try.", "name": "Bright cup", "doseG": dose, "waterG": water, "tempC": 94,
      "totalTimeS": 180,
      "steps": [
        ["kind": "bloom", "atS": 0, "waterG": dose * 3, "instruction": "Bloom."],
        ["kind": "pour", "atS": 45, "waterG": water, "instruction": "Pour the rest slowly."],
      ],
    ]
  }

  private func sanity(note: String = "", from: RecipeDraft? = nil) -> RecipeReviewAI.Sanity {
    let method = BrewMethod()
    method.builtInKey = "cone-dripper"
    return RecipeReviewAI.Sanity(method: method, note: note, from: from)!
  }

  private func fit(
    _ first: RecipeDraft, sanity: RecipeReviewAI.Sanity, second: [String: Any]
  ) async throws -> (review: RecipeReviewAI.Review, asked: [String]) {
    var asked: [String] = []
    let review = try await RecipeReviewAI.fit(
      RecipeReviewAI.Review(summary: "First try.", changes: [], draft: first, source: "Test"),
      brewer: nil, payload: RecipeReviewAI.createPayload(methodName: "V60", style: "", note: ""),
      base: RecipeDraft(), mode: .create, sanity: sanity,
      send: {
        asked.append($0.userText)
        return (second, "Test")
      })
    return (review, asked)
  }

  @Test func aSoundAnswerIsNotAskedForAgain() async throws {
    let result = try await fit(
      draft(dose: 15, water: 250), sanity: sanity(), second: answer(dose: 1, water: 1))
    #expect(result.asked.isEmpty && result.review.summary == "First try.")
  }

  @Test func wrongNumbersAreAskedForAgainOnceWithTheProblem() async throws {
    let result = try await fit(
      draft(dose: 10, water: 400), sanity: sanity(), second: answer(dose: 15, water: 250))
    #expect(result.asked.count == 1)
    #expect(result.asked.first?.contains("its ratio is 1:40") == true)
    #expect(result.review.summary == "Second try." && result.review.draft.waterG == 250)
  }

  @Test func numbersStillWrongAreThrownAway() async {
    await #expect(throws: AIError.invalidResponse) {
      _ = try await fit(
        draft(dose: 10, water: 400), sanity: sanity(), second: answer(dose: 10, water: 400))
    }
  }

  /// "1:10, strong" is the user's call: the AI is asked once more, then believed.
  @Test func aNoteThatNamesNumbersComesFirst() async throws {
    let asked = sanity(note: "strong, 1:10")
    #expect(!asked.strict && sanity(note: "bright and sweet").strict)
    let result = try await fit(
      draft(dose: 20, water: 200), sanity: asked, second: answer(dose: 20, water: 200))
    #expect(result.asked.count == 1 && result.review.summary == "First try.")
  }

  @Test func theSitesAreBareDomainsBothProvidersAccept() {
    for site in RecipeReviewAI.researchSites {
      #expect(!site.contains("/") && !site.contains(":") && !site.hasPrefix("www."), "\(site)")
      #expect(site.contains(".") && site == site.lowercased())
    }
    #expect(Set(RecipeReviewAI.researchSites).count == RecipeReviewAI.researchSites.count)
    #expect(RecipeReviewAI.researchSites.count <= 100, "OpenAI's limit")
  }
}
