import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("COULD set: TDS, water profiles, App Intents")
struct CouldSetTests {
  @MainActor
  private struct Harness {
    let container: ModelContainer
    let store: Store
    let draftStore: DraftStore

    init() throws {
      container = try NextCupContainer.make(inMemory: true)
      store = Store(context: container.mainContext)
      draftStore = DraftStore(
        fileURL: FileManager.default.temporaryDirectory
          .appendingPathComponent("nextcup-could-\(UUID().uuidString)/brew-draft.json"))
    }

    func model(editing: Brew? = nil, repeating: Brew? = nil) -> BrewFormModel {
      BrewFormModel(
        seed: nil, editing: editing, repeating: repeating, store: store, draftStore: draftStore,
        defaults: UserDefaults(suiteName: "nextcup.could.\(UUID().uuidString)") ?? .standard)
    }
  }

  // MARK: TDS and extraction

  @Test func tdsStepsAndClears() throws {
    let model = try Harness().model()
    model.stepTds(direction: 1)
    #expect(model.draft.tds == BrewFormModel.defaultTds)
    model.stepTds(direction: 1)
    #expect(abs((model.draft.tds ?? 0) - 1.40) < 0.0001)
    model.draft.tds = 0.05
    model.stepTds(direction: -1)
    #expect(model.draft.tds == nil)
  }

  @Test func extractionNeedsTdsDoseAndWater() throws {
    let model = try Harness().model()
    #expect(model.extractionLabel == nil)
    model.draft.doseG = 15
    model.draft.waterG = 250
    #expect(model.extractionLabel == nil)
    model.draft.tds = 1.35
    // 1.35 × 250 ÷ 15 = 22.5
    #expect(model.extractionLabel == "22.5%")
  }

  @Test func tdsAndWaterSurviveSaveAndEdit() throws {
    let harness = try Harness()
    let first = harness.model()
    first.draft.doseG = 15
    first.draft.waterG = 250
    first.draft.tds = 1.4
    #expect(first.addWaterProfile(named: "Filtered", hardnessPPM: "75"))
    #expect(first.save())

    let brew = try #require(try harness.store.find(Brew.self, id: first.draft.id))
    #expect(brew.tds == 1.4)
    #expect(brew.waterProfile?.name == "Filtered")
    #expect(brew.waterProfile?.ppmHardness == 75)

    let edit = harness.model(editing: brew)
    #expect(edit.draft.tds == 1.4)
    #expect(edit.draft.waterProfileID == brew.waterProfile?.id)
  }

  @Test func brewAgainKeepsWaterButNotTds() throws {
    let harness = try Harness()
    let first = harness.model()
    first.draft.doseG = 15
    first.draft.waterG = 250
    first.draft.tds = 1.4
    first.addWaterProfile(named: "Filtered")
    first.save()
    let source = try #require(try harness.store.find(Brew.self, id: first.draft.id))

    let again = harness.model(repeating: source)
    #expect(again.draft.waterProfileID == source.waterProfile?.id)
    #expect(again.draft.tds == nil)
  }

  @Test func tdsIsOfferedAsATrackedParameter() {
    #expect(MethodParameters.optional.contains(.tds))
    #expect(MethodParameters.shown(tracked: [.tds]).contains(.tds))
  }

  // MARK: Water profiles

  @Test func waterProfileRefusesBadInputAndDeduplicates() throws {
    let harness = try Harness()
    let model = harness.model()
    #expect(!model.addWaterProfile(named: "  "))
    #expect(!model.addWaterProfile(named: "Tap", hardnessPPM: "soft"))
    #expect(!model.addWaterProfile(named: "Tap", hardnessPPM: "-5"))
    #expect(try harness.store.context.fetch(FetchDescriptor<WaterProfile>()).isEmpty)

    #expect(model.addWaterProfile(named: "Tap", hardnessPPM: "120"))
    let id = model.draft.waterProfileID
    model.setWaterProfile(nil)
    #expect(model.addWaterProfile(named: "tap"))
    #expect(model.draft.waterProfileID == id)
    #expect(try harness.store.context.fetch(FetchDescriptor<WaterProfile>()).count == 1)
  }

  /// The decimal pad shows "," in comma locales, so "7,5" is read as 7.5.
  @Test func waterHardnessTakesADecimalComma() throws {
    let harness = try Harness()
    let model = harness.model()
    #expect(model.addWaterProfile(named: "Soft", hardnessPPM: "7,5"))
    let profile = try #require(
      try harness.store.context.fetch(FetchDescriptor<WaterProfile>()).first)
    #expect(profile.ppmHardness == 7.5)
  }

  @Test func deletingAWaterProfileKeepsTheBrew() throws {
    let harness = try Harness()
    let model = harness.model()
    model.draft.doseG = 15
    model.draft.waterG = 250
    model.addWaterProfile(named: "Rain")
    model.save()
    let profile = try #require(
      try harness.store.context.fetch(FetchDescriptor<WaterProfile>()).first)
    harness.store.context.delete(profile)
    _ = harness.store.save()
    let brew = try #require(try harness.store.find(Brew.self, id: model.draft.id))
    #expect(brew.waterProfile == nil)
  }

  // MARK: App Intents

  @Test func logBrewOpensANewBrew() {
    #expect(IntentLinks.logBrew == .newBrew)
  }

  @Test func brewAgainPicksTheLatestSavedBrew() throws {
    let harness = try Harness()
    let context = harness.container.mainContext
    #expect(IntentLinks.brewAgain(in: context) == nil)

    let older = Brew(date: Date(timeIntervalSince1970: 1_000))
    let newer = Brew(date: Date(timeIntervalSince1970: 2_000))
    for brew in [older, newer] { context.insert(brew) }
    _ = harness.store.save()
    #expect(IntentLinks.brewAgain(in: context) == .brewAgain(newer.id))
  }

  @Test func startRecipeLinksToTheTimerAtTheRecipeDose() throws {
    let harness = try Harness()
    let context = harness.container.mainContext
    let recipe = Recipe(name: "Test cone", doseG: 15, waterG: 250)
    let empty = Recipe(name: "No dose", doseG: 0, waterG: 0)
    context.insert(recipe)
    context.insert(empty)
    _ = harness.store.save()

    #expect(
      IntentLinks.startRecipe(id: recipe.id, in: context) == .timer(recipeID: recipe.id, doseG: 15))
    #expect(IntentLinks.startRecipe(id: empty.id, in: context) == nil)
    #expect(IntentLinks.startRecipe(id: UUID(), in: context) == nil)
  }
}
