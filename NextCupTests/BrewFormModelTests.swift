import CoreGraphics
import Foundation
import ImageIO
import NextCupKit
import SwiftData
import Testing
import UniformTypeIdentifiers

@testable import NextCup

@MainActor
@Suite("BrewFormModel")
struct BrewFormModelTests {
  /// Holds the container so the context stays valid for the whole test.
  @MainActor
  private struct Harness {
    let container: ModelContainer
    let store: Store
    let draftStore: DraftStore
    let defaults: UserDefaults

    init() throws {
      container = try NextCupContainer.make(inMemory: true)
      store = Store(context: container.mainContext)
      draftStore = DraftStore(
        fileURL: FileManager.default.temporaryDirectory
          .appendingPathComponent("nextcup-form-\(UUID().uuidString)/brew-draft.json"))
      defaults = UserDefaults(suiteName: "nextcup.formtests.\(UUID().uuidString)") ?? .standard
    }

    func model(
      seed: BrewFormSeed? = nil, editing: Brew? = nil, failSave: Bool = false
    ) -> BrewFormModel {
      BrewFormModel(
        seed: seed, editing: editing, store: store, draftStore: draftStore, defaults: defaults,
        simulatesSaveFailure: failSave)
    }

    func brews() throws -> [Brew] { try container.mainContext.fetch(FetchDescriptor<Brew>()) }
  }

  private func seed(key: String = "run-1") -> BrewFormSeed {
    BrewFormSeed(
      sessionKey: key, recipeID: UUID(), recipeName: "Test cone", methodName: "Cone",
      doseG: 15, waterG: 250, tempC: 94, totalTimeS: 187, targetTimeS: 180, endedEarly: false)
  }

  private func jpegWithGPS() throws -> Data {
    let context = try #require(
      CGContext(
        data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
    let output = NSMutableData()
    let destination = try #require(
      CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
    let properties: [CFString: Any] = [
      kCGImagePropertyGPSDictionary: [
        kCGImagePropertyGPSLatitude: 37.33, kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 122.03, kCGImagePropertyGPSLongitudeRef: "W",
      ],
      kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "home kitchen"],
    ]
    CGImageDestinationAddImage(
      destination, try #require(context.makeImage()), properties as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return output as Data
  }

  private func metadata(of data: Data) throws -> [CFString: Any] {
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
  }

  // MARK: Autosave and restore

  @Test func flushedDraftIsRestoredByTheNextOpen() throws {
    let harness = try Harness()
    let first = harness.model()
    first.draft.doseG = 16
    first.draft.grindSetting = "21 clicks"
    first.draft.notes = "Sweet, a bit short."
    first.flushDraft()

    let reopened = harness.model()
    #expect(reopened.draft == first.draft)
    #expect(reopened.notice?.message == "Restored your unsaved brew.")
  }

  @Test func seededFormRestoresItsOwnDraftButNotAnotherRuns() throws {
    let harness = try Harness()
    let first = harness.model(seed: seed(key: "run-1"))
    first.draft.notes = "typed after the timer"
    first.flushDraft()

    #expect(harness.model(seed: seed(key: "run-1")).draft.notes == "typed after the timer")
    let other = harness.model(seed: seed(key: "run-2"))
    #expect(other.draft.notes.isEmpty)
    #expect(other.draft.totalTimeS == 187)
  }

  @Test func seedFillsActualValuesAndKeepsTargetsSeparate() throws {
    let harness = try Harness()
    let model = harness.model(seed: seed())
    #expect(model.draft.doseG == 15)
    #expect(model.draft.totalTimeS == 187)
    #expect(model.draft.targets?.totalTimeS == 180)
    model.draft.totalTimeS = 200
    #expect(model.draft.targets?.totalTimeS == 180)
  }

  @Test func corruptDraftIsDiscardedWithANotice() throws {
    let harness = try Harness()
    try FileManager.default.createDirectory(
      at: harness.draftStore.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("garbage".utf8).write(to: harness.draftStore.fileURL)
    let model = harness.model()
    #expect(model.draft.doseG == nil)
    #expect(model.notice?.message.contains("discarded") == true)
  }

  @Test func failedAutosaveIsShownAndTheDraftStaysInMemory() throws {
    let harness = try Harness()
    struct Boom: Error {}
    let model = BrewFormModel(
      seed: nil, store: harness.store,
      draftStore: DraftStore(fileURL: harness.draftStore.fileURL) { _, _ in throw Boom() },
      defaults: harness.defaults)
    model.draft.notes = "still here"
    model.flushDraft()
    #expect(model.notice?.kind == .error)
    #expect(model.draft.notes == "still here")
  }

  // MARK: Honest saves

  @Test func saveWritesTheBrewAndClearsTheDraftAfterTheWrite() throws {
    let harness = try Harness()
    let model = harness.model(seed: seed())
    model.draft.grindSetting = " 21 clicks "
    model.draft.verdict = Verdict.sour.rawValue
    model.draft.ratingHalfSteps = 7
    #expect(harness.draftStore.load() != .none)

    #expect(model.save())
    let brews = try harness.brews()
    #expect(brews.count == 1)
    #expect(brews[0].doseG == 15)
    #expect(brews[0].totalTimeS == 187)
    #expect(brews[0].grindSetting == "21 clicks")
    #expect(brews[0].verdict == .sour)
    #expect(brews[0].ratingHalfSteps == 7)
    #expect(brews[0].isDraft == false)
    #expect(brews[0].targetsJSON != nil)
    #expect(harness.draftStore.load() == .none)
    #expect(model.savedBrewID == brews[0].id)
  }

  @Test func savingTwiceDoesNotCreateASecondBrew() throws {
    let harness = try Harness()
    let model = harness.model(seed: seed())
    #expect(model.save())
    #expect(!model.save())
    #expect(try harness.brews().count == 1)
  }

  @Test func simulatedWriteFailureShowsAnErrorAndKeepsTheDraft() throws {
    let harness = try Harness()
    let model = harness.model(seed: seed(), failSave: true)
    model.draft.notes = "do not lose me"
    #expect(!model.save())
    #expect(model.saveError?.contains("Not saved") == true)
    #expect(model.savedBrewID == nil)
    #expect(try harness.brews().isEmpty)
    guard case .draft(let kept) = harness.draftStore.load() else {
      Issue.record("draft was not kept after a failed save")
      return
    }
    #expect(kept.notes == "do not lose me")
    #expect(model.draft.notes == "do not lose me")
    #expect(model.canSave)
  }

  @Test func saveNeedsDoseAndWater() throws {
    let harness = try Harness()
    let model = harness.model()
    #expect(!model.canSave)
    #expect(!model.save())
    model.draft.doseG = 15
    model.draft.waterG = 250
    #expect(model.canSave)
    #expect(model.ratioLabel == "1:16.7")
  }

  @Test func lastUsedMethodIsRememberedForTheNextBlankForm() throws {
    let harness = try Harness()
    let first = BrewMethod(name: "First", style: .pourOver)
    first.sortOrder = 0
    let second = BrewMethod(name: "Second", style: .immersion)
    second.sortOrder = 1
    harness.container.mainContext.insert(first)
    harness.container.mainContext.insert(second)

    let model = harness.model()
    #expect(model.draft.methodID == first.id)
    model.draft.methodID = second.id
    model.draft.doseG = 15
    model.draft.waterG = 250
    #expect(model.save())
    #expect(harness.model().draft.methodID == second.id)
  }

  // MARK: Editing a saved brew

  private func savedBrew(_ harness: Harness) throws -> Brew {
    let first = harness.model()
    first.draft.doseG = 15
    first.draft.waterG = 250
    first.draft.grindSetting = "21 clicks"
    first.draft.verdict = Verdict.sour.rawValue
    first.draft.ratingHalfSteps = 7
    first.draft.notes = "Sweet, a bit short."
    #expect(first.save())
    return try #require(try harness.brews().first)
  }

  @Test func editOpensWithTheSavedValuesAndSavesOverTheSameBrew() throws {
    let harness = try Harness()
    let brew = try savedBrew(harness)
    let model = harness.model(editing: brew)
    #expect(model.isEditing)
    #expect(model.draft.id == brew.id)
    #expect(model.draft.doseG == 15)
    #expect(model.draft.grindSetting == "21 clicks")
    #expect(model.draft.verdict == Verdict.sour.rawValue)
    #expect(model.draft.ratingHalfSteps == 7)
    #expect(model.notice == nil)

    model.draft.doseG = 16
    model.draft.notes = "Sweeter at 16 g."
    #expect(model.save())
    let brews = try harness.brews()
    #expect(brews.count == 1, "an edit never makes a second brew")
    #expect(brews[0].doseG == 16)
    #expect(brews[0].notes == "Sweeter at 16 g.")
    #expect(brews[0].grindSetting == "21 clicks")
  }

  @Test func editDraftRestoresForTheSameBrewOnly() throws {
    let harness = try Harness()
    let brew = try savedBrew(harness)
    let first = harness.model(editing: brew)
    first.draft.notes = "unsaved edit"
    first.flushDraft()

    #expect(harness.model(editing: brew).draft.notes == "unsaved edit")
    let other = Brew()
    harness.container.mainContext.insert(other)
    #expect(harness.model(editing: other).draft.id == other.id)
    #expect(harness.model(editing: other).draft.notes.isEmpty)
  }

  @Test func failedEditSaveKeepsTheSavedBrewAndTheEditedDraft() throws {
    let harness = try Harness()
    let brew = try savedBrew(harness)
    let model = harness.model(editing: brew, failSave: true)
    model.draft.doseG = 18
    #expect(!model.save())
    #expect(model.saveError != nil)
    #expect(try harness.brews().first?.doseG == 15)
    #expect(model.draft.doseG == 18)
  }

  // MARK: Stepping in the user's units

  @Test func stepsChangeWhatIsShownInOunces() throws {
    let harness = try Harness()
    let model = harness.model()
    let ounces = UnitPreferences(weight: .ounces)
    model.draft.doseG = 15
    model.stepWeight(
      \.doseG, direction: 1, units: ounces, gramStep: 0.1, ounceStep: 0.01, start: 15)
    let shown = ounces.displayWeight(grams: try #require(model.draft.doseG))
    #expect(abs(shown - 0.54) < 0.0001, "0.53 oz plus one 0.01 oz step, got \(shown)")
  }

  @Test func firstTapStartsFromTheDefault() throws {
    let harness = try Harness()
    let model = harness.model()
    model.stepWeight(
      \.waterG, direction: -1, units: UnitPreferences(), gramStep: 1, ounceStep: 0.05,
      start: BrewFormModel.defaultWaterG)
    #expect(model.draft.waterG == 250)
    model.stepTime(direction: 1)
    #expect(model.draft.totalTimeS == 180)
    model.stepTime(direction: 1)
    #expect(model.draft.totalTimeS == 185)
  }

  // MARK: Photo privacy

  @Test func attachedPhotoHasNoLocationAndIsWhatGetsStored() async throws {
    let harness = try Harness()
    let original = try jpegWithGPS()
    #expect(try metadata(of: original)[kCGImagePropertyGPSDictionary] != nil)

    let model = harness.model()
    model.draft.doseG = 15
    model.draft.waterG = 250
    await model.attachPhoto(original)
    #expect(model.photoError == nil)
    #expect(model.save())

    let stored = try #require(try harness.brews().first?.photo)
    let properties = try metadata(of: stored)
    #expect(properties[kCGImagePropertyGPSDictionary] == nil)
    let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
    #expect(exif[kCGImagePropertyExifUserComment] == nil)
    #expect(!String(decoding: stored, as: UTF8.self).contains("home kitchen"))
  }

  @Test func aFileThatIsNotAPhotoAttachesNothing() async throws {
    let harness = try Harness()
    let model = harness.model()
    await model.attachPhoto(Data("not an image".utf8))
    #expect(model.draft.photo == nil)
    #expect(model.photoError != nil)
  }
}
