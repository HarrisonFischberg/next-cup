import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Recipe editor")
struct RecipeEditorTests {
  @MainActor
  private struct Harness {
    let container: ModelContainer
    let service: RecipeEditorService
    let method: BrewMethod

    init() throws {
      container = try NextCupContainer.make(inMemory: true)
      service = RecipeEditorService(store: Store(context: container.mainContext))
      method = BrewMethod(name: "Cone dripper")
      container.mainContext.insert(method)
      try container.mainContext.save()
    }

    func makeDraft() -> RecipeDraft {
      var draft = RecipeDraft()
      draft.name = "  Morning cone  "
      draft.methodID = method.id
      draft.doseG = 15
      draft.waterG = 250
      draft.tempC = 94
      draft.totalTimeS = 180
      draft.tuningNote = "Grind finer if sour."
      draft.credit = "House"
      draft.steps = [
        RecipeStepDraft(
          kind: .pour, startOffsetS: 45, targetCumulativeWaterG: 250, instruction: "Pour."),
        RecipeStepDraft(
          kind: .bloom, startOffsetS: 0, targetCumulativeWaterG: 45, instruction: "Bloom."),
        RecipeStepDraft(kind: .drawdown, startOffsetS: 120, instruction: ""),
      ]
      return draft
    }
  }

  // MARK: Round trip

  @Test func savedDraftReadsBackIdentically() throws {
    let harness = try Harness()
    let saved = try harness.service.save(harness.makeDraft()).get()
    #expect(saved.name == "Morning cone")
    #expect(saved.method?.id == harness.method.id)
    #expect(saved.orderedSteps.map(\.kind) == [.bloom, .pour, .drawdown])
    #expect(saved.orderedSteps.map(\.order) == [0, 1, 2])

    let read = harness.service.draft(from: saved, asCopy: false)
    #expect(read.sourceID == saved.id)
    #expect(read.name == "Morning cone")
    #expect(read.doseG == 15 && read.waterG == 250 && read.tempC == 94 && read.totalTimeS == 180)
    #expect(read.tuningNote == "Grind finer if sour." && read.credit == "House")
    #expect(read.steps.map(\.kind) == [.bloom, .pour, .drawdown])
    #expect(read.steps.map(\.startOffsetS) == [0, 45, 120])
    #expect(read.steps.map(\.targetCumulativeWaterG) == [45, 250, nil])
    #expect(read.steps.map(\.instruction) == ["Bloom.", "Pour.", ""])
  }

  @Test func everyStepKindSurvivesASaveAndReload() throws {
    let harness = try Harness()
    var draft = harness.makeDraft()
    draft.steps = StepKind.allCases.enumerated().map { index, kind in
      RecipeStepDraft(kind: kind, startOffsetS: index * 10)
    }
    let saved = try harness.service.save(draft).get()
    let reloaded = try #require(
      try Store(context: harness.container.mainContext).find(Recipe.self, id: saved.id))
    #expect(reloaded.orderedSteps.map(\.kind) == StepKind.allCases)
  }

  @Test func editingInPlaceReplacesStepsWithoutLeavingOrphans() throws {
    let harness = try Harness()
    let saved = try harness.service.save(harness.makeDraft()).get()
    var draft = harness.service.draft(from: saved, asCopy: false)
    draft.name = "Renamed"
    draft.steps.removeLast()
    let edited = try harness.service.save(draft).get()
    #expect(edited.id == saved.id)
    let context = harness.container.mainContext
    #expect(try context.fetch(FetchDescriptor<Recipe>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<RecipeStep>()).count == 2)
    #expect(edited.name == "Renamed")
  }

  // MARK: Customized copy

  @Test func customizingABuiltInSavesACopyAndLeavesTheOriginal() throws {
    let harness = try Harness()
    let context = harness.container.mainContext
    let builtIn = Recipe(name: "Balanced cone", doseG: 15, waterG: 250)
    builtIn.builtInKey = "cone-balanced"
    builtIn.credit = "Next Cup"
    context.insert(builtIn)
    builtIn.steps = [RecipeStep(order: 0, kind: .bloom, startOffsetS: 0)]
    try context.save()

    var draft = harness.service.draft(from: builtIn, asCopy: true)
    #expect(draft.sourceID == nil)
    #expect(draft.name == "Balanced cone (copy)")
    draft.doseG = 18
    let copy = try harness.service.save(draft).get()

    #expect(copy.id != builtIn.id)
    #expect(copy.builtInKey == nil)
    #expect(copy.doseG == 18)
    #expect(copy.credit == "Next Cup")
    #expect(builtIn.doseG == 15 && builtIn.name == "Balanced cone")
    #expect(builtIn.builtInKey == "cone-balanced")
    #expect(builtIn.orderedSteps.count == 1)
    #expect(try context.fetch(FetchDescriptor<Recipe>()).count == 2)
  }

  @Test func aRecipeAtANewSizeBecomesItsOwnRecipeWithScaledSteps() throws {
    let harness = try Harness()
    let context = harness.container.mainContext
    let builtIn = Recipe(name: "Steep then release", doseG: 18, waterG: 270)
    builtIn.builtInKey = "switchable-steep"
    builtIn.tempC = 94
    builtIn.totalTimeS = 210
    context.insert(builtIn)
    let pour = RecipeStep(order: 0, kind: .pour, startOffsetS: 0)
    pour.targetCumulativeWaterG = 270
    pour.instruction = "Pour 270 g quickly."
    builtIn.steps = [pour, RecipeStep(order: 1, kind: .openValve, startOffsetS: 120)]
    try context.save()

    let draft = harness.service.draft(
      from: builtIn, scaledTo: 41, tuning: nil, name: "Steep then release (18 oz)")
    #expect(draft.sourceID == nil)
    #expect(draft.name == "Steep then release (18 oz)")
    #expect(draft.doseG == 41)
    #expect(abs(draft.waterG - 615) < 0.5)
    #expect(abs((draft.steps[0].targetCumulativeWaterG ?? 0) - 615) < 0.5)
    #expect(draft.steps[0].instruction == "Pour 615 g quickly.")
    // Immersion keeps its steep time.
    #expect(draft.steps[1].startOffsetS == 120)

    let copy = try harness.service.save(draft).get()
    #expect(copy.id != builtIn.id && copy.builtInKey == nil)
    #expect(builtIn.doseG == 18 && builtIn.orderedSteps.first?.targetCumulativeWaterG == 270)
  }

  // MARK: Validation

  @Test func rejectsBadRecipesBeforeTouchingTheStore() throws {
    let harness = try Harness()
    func problem(_ change: (inout RecipeDraft) -> Void) -> RecipeEditorError? {
      var draft = harness.makeDraft()
      change(&draft)
      return RecipeEditorService.validate(draft)
    }
    #expect(problem { $0.name = "   " } == .emptyName)
    #expect(problem { $0.doseG = 0 } == .invalidDose)
    #expect(problem { $0.waterG = -1 } == .invalidWater)
    #expect(
      problem {
        $0.includesIce = true
        $0.iceG = nil
      } == .invalidIce)
    #expect(problem { $0.steps[0].startOffsetS = -5 } == .negativeTime(step: 1))
    #expect(problem { $0.steps[0].targetCumulativeWaterG = 400 } == .targetExceedsWater(step: 2))
    #expect(problem { $0.steps[0].targetCumulativeWaterG = 30 } == .targetGoesBackwards(step: 2))
    #expect(problem { _ in } == nil)

    var draft = harness.makeDraft()
    draft.doseG = 0
    if case .failure(let error) = harness.service.save(draft) { #expect(error == .invalidDose) }
    #expect(try harness.container.mainContext.fetch(FetchDescriptor<Recipe>()).isEmpty)
  }

  @Test func iceCountsTowardTheWaterATargetMayReach() throws {
    let harness = try Harness()
    var draft = harness.makeDraft()
    draft.includesIce = true
    draft.iceG = 100
    draft.steps[0].targetCumulativeWaterG = 340
    #expect(RecipeEditorService.validate(draft) == nil)
  }

  // MARK: Text fields

  @Test func fieldsRoundTripThroughDisplayUnits() throws {
    let harness = try Harness()
    let saved = try harness.service.save(harness.makeDraft()).get()
    let ounces = UnitPreferences(weight: .ounces, temperature: .fahrenheit)
    let fields = RecipeEditorFields(
      draft: harness.service.draft(from: saved, asCopy: false), units: ounces)
    #expect(fields.temperature == "201")
    #expect(fields.time == "3:00")
    let back = try fields.draft(units: ounces).get()
    #expect(abs(back.doseG - 15) < 0.05)
    #expect(abs(back.waterG - 250) < 0.05)
    #expect(abs((back.tempC ?? 0) - 94) < 0.3)
    #expect(back.totalTimeS == 180)
    #expect(back.steps.map(\.kind) == [.bloom, .pour, .drawdown])
  }

  @Test func fieldsParseCommasClocksAndNameTheUnreadableField() throws {
    var fields = RecipeEditorFields()
    fields.name = "Test"
    fields.dose = "18,5"
    fields.water = "300"
    fields.time = "2:30"
    fields.steps = [
      RecipeEditorFields.StepFields(kind: .stir, time: "75", water: "", instruction: "")
    ]
    let draft = try fields.draft(units: UnitPreferences()).get()
    #expect(draft.doseG == 18.5)
    #expect(draft.totalTimeS == 150)
    #expect(draft.steps[0].startOffsetS == 75)

    fields.steps[0].time = "1:75"
    if case .failure(let error) = fields.draft(units: UnitPreferences()) {
      #expect(error == .unreadable(field: "Step 1 time"))
    } else {
      Issue.record("an unreadable step time must fail")
    }
    fields.steps[0].time = "0:10"
    fields.dose = "abc"
    if case .failure(let error) = fields.draft(units: UnitPreferences()) {
      #expect(error == .unreadable(field: "Dose"))
    } else {
      Issue.record("an unreadable dose must fail")
    }
  }

  // MARK: Delete

  @Test func deletingAUserRecipeKeepsItsBrewsAndRemovesItsSteps() throws {
    let harness = try Harness()
    let context = harness.container.mainContext
    let recipe = try harness.service.save(harness.makeDraft()).get()
    let brew = Brew()
    brew.method = harness.method
    brew.recipe = recipe
    brew.doseG = 15
    brew.notes = "Bright."
    context.insert(brew)
    try context.save()

    try harness.service.delete(recipe).get()

    #expect(try context.fetch(FetchDescriptor<Recipe>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<RecipeStep>()).isEmpty)
    let kept = try #require(try context.fetch(FetchDescriptor<Brew>()).first)
    #expect(kept.recipe == nil)
    #expect(kept.method?.id == harness.method.id)
    #expect(kept.doseG == 15 && kept.notes == "Bright.")
  }

  @Test func builtInRecipesCannotBeDeleted() throws {
    let harness = try Harness()
    let builtIn = Recipe(name: "Balanced cone", doseG: 15, waterG: 250)
    builtIn.builtInKey = "cone-balanced"
    harness.container.mainContext.insert(builtIn)
    try harness.container.mainContext.save()

    #expect(throws: RecipeEditorError.builtIn) { try harness.service.delete(builtIn).get() }
    #expect(try harness.container.mainContext.fetch(FetchDescriptor<Recipe>()).count == 1)
  }

  // MARK: Bundled content

  @Test func bundleHasTheSwitchableDripperAndInvertedPressWithTheirOwnSteps() throws {
    let content = try BuiltInContent(bundle: .main)
    let switchable = try #require(content.methods.first { $0.key == "switchable-dripper" })
    let inverted = try #require(content.methods.first { $0.key == "inverted-press" })
    #expect(switchable.defaultStepKinds.contains(.closeValve))
    #expect(switchable.defaultStepKinds.contains(.openValve))
    #expect(inverted.defaultStepKinds.contains(.plug))
    #expect(inverted.defaultStepKinds.contains(.invert))
    #expect(content.recipes.contains { $0.methodKey == "switchable-dripper" })
    #expect(content.recipes.contains { $0.methodKey == "inverted-press" })
  }
}
