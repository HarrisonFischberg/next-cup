import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Paper import")
struct PaperImportAppTests {
  private static var containers: [ModelContainer] = []

  private func make() throws -> ModelContext {
    // A dropped container crashes the test host, so keep every one alive.
    let container = try NextCupContainer.make(inMemory: true)
    Self.containers.append(container)
    return container.mainContext
  }

  private func model(_ context: ModelContext) -> PaperImportModel {
    PaperImportModel(store: Store(context: context))
  }

  private func read(_ model: PaperImportModel, page: [String] = PaperSample.lines) async {
    await model.choose(photoData: PaperSample.page(page))
    model.readOnDevice()
    for _ in 0..<200 where model.phase == .reading {
      try? await Task.sleep(for: .milliseconds(100))
    }
  }

  // MARK: Field mapping from a synthetic image

  @Test func syntheticPageIsRecognizedAndMapped() async throws {
    let context = try make()
    let model = model(context)
    await read(model)
    #expect(model.phase == .review)
    let draft = model.draft
    #expect(draft.method == "V60")
    #expect(draft.bean == "Sample Blend")
    #expect(draft.doseG == 18)
    #expect(draft.waterG == 288)
    #expect(draft.tempC == 94)
    #expect(draft.totalTimeS == 165)
    #expect(draft.grind == "24")
    #expect(draft.ratingHalfSteps == 8)
    #expect(draft.notes.contains("sweet"))
    #expect(try context.fetch(FetchDescriptor<Brew>()).isEmpty, "reading never saves")
  }

  @Test func aPageWithNoTextIsAnErrorNotADraft() async throws {
    let model = model(try make())
    await read(model, page: [])
    #expect(model.phase == .choose)
    #expect(model.errorMessage != nil)
  }

  @Test func aFileThatIsNotAPhotoImportsNothing() async throws {
    let model = model(try make())
    await model.choose(photoData: Data("not an image".utf8))
    #expect(model.photo == nil)
    #expect(model.errorMessage != nil)
  }

  // MARK: Save is blocked until confirmed

  @Test func nothingIsSavedUntilTheUserConfirms() async throws {
    let context = try make()
    let model = model(context)
    await read(model)
    #expect(!model.canSave)
    #expect(!model.save())
    #expect(try context.fetch(FetchDescriptor<Brew>()).isEmpty)

    model.confirmed = true
    #expect(model.canSave)
    #expect(model.save())
    #expect(try context.fetch(FetchDescriptor<Brew>()).count == 1)
  }

  @Test func editingTakesTheConfirmationBack() async throws {
    let model = model(try make())
    await read(model)
    model.confirmed = true
    model.draft.doseG = 20
    #expect(!model.confirmed)
    model.confirmed = true
    model.date = Date(timeIntervalSinceNow: -86_400)
    #expect(!model.confirmed)
    model.confirmed = true
    model.methodID = UUID()
    #expect(!model.confirmed)
  }

  @Test func savingTwiceMakesOneBrew() async throws {
    let context = try make()
    let model = model(context)
    await read(model)
    model.confirmed = true
    #expect(model.save())
    model.confirmed = true
    #expect(model.save())
    #expect(try context.fetch(FetchDescriptor<Brew>()).count == 1)
  }

  // MARK: Auto-filing

  @Test func savedBrewIsFiledUnderTheMatchingMethodAndBean() async throws {
    let context = try make()
    let method = BrewMethod()
    method.name = "Hario V60"
    context.insert(method)
    let bean = Bean(name: "Sample Blend")
    bean.bagWeightG = 250
    context.insert(bean)
    try context.save()

    let model = model(context)
    await read(model)
    #expect(model.methodID == method.id)
    model.confirmed = true
    #expect(model.save())

    let brew = try #require(context.fetch(FetchDescriptor<Brew>()).first)
    #expect(brew.method?.id == method.id)
    #expect(brew.doseG == 18)
    #expect(brew.totalTimeS == 165)
    #expect(brew.ratingHalfSteps == 8)
    #expect(brew.isDraft == false)
    #expect(brew.photo != nil)
    let use = try #require(brew.beans?.first)
    #expect(use.bean?.id == bean.id)
    #expect(use.grams == 18)
  }

  @Test func anUnknownBeanIsKeptAsAWrittenNameAndNoBeanIsCreated() async throws {
    let context = try make()
    let model = model(context)
    await read(model)
    model.confirmed = true
    #expect(model.save())
    let use = try #require(context.fetch(FetchDescriptor<Brew>()).first?.beans?.first)
    #expect(use.bean == nil)
    #expect(use.beanNameSnapshot == "Sample Blend")
    #expect(try context.fetch(FetchDescriptor<Bean>()).isEmpty)
  }

  @Test func namesMatchExactlyOrByContainment() {
    let id = UUID()
    let names = [(id, "Hario V60"), (UUID(), "AeroPress")]
    #expect(PaperImportModel.match("v60", among: names) == id)
    #expect(PaperImportModel.match("Hario  V60 02", among: names) == id)
    #expect(PaperImportModel.match("Aero", among: names) != id)
    #expect(PaperImportModel.match("V6", among: names) == nil, "under three letters is exact only")
    #expect(PaperImportModel.match("", among: names) == nil)
  }

  // MARK: AI reading

  private let answer = """
    {"method":"V60","bean":"Sample Blend","doseGrams":18,"waterGrams":288,"temperatureCelsius":94,\
    "timeSeconds":165,"grind":"24","ratingOutOfFive":4,"notes":"sweet","uncertain":"grind"}
    """

  private func aiModel(_ context: ModelContext, body: String, key: String?) -> (
    PaperImportModel, PaperImportStubTransport
  ) {
    let stub = PaperImportStubTransport(body)
    let client = AIClient(
      transport: stub, key: { _ in key }, disclosureAccepted: { _ in true }, sleep: { _ in })
    let model = PaperImportModel(
      store: Store(context: context), makeQueue: { AIQueue(context: $0, client: client) })
    return (model, stub)
  }

  /// The model reads the user's choice from the standard defaults, so a test sets it
  /// and the returned cleanup removes it again.
  private func chooseAI() -> () -> Void {
    AIPreferences().setChoice(.anthropic, model: "test-model", for: .paperImport)
    return {
      UserDefaults.standard.removeObject(forKey: AIPreferences.providerKey(.paperImport))
      UserDefaults.standard.removeObject(forKey: AIPreferences.modelKey(.paperImport))
    }
  }

  @Test func aiAnswerOpensTheReviewWithItsDoubtsAndSavesNothing() async throws {
    let cleanup = chooseAI()
    defer { cleanup() }
    let context = try make()
    let (model, stub) = aiModel(
      context, body: #"{"content":[{"type":"text","text":"\#(answer.escapedForJSON)"}]}"#,
      key: "sk-test")
    await model.choose(photoData: PaperSample.page())
    model.readWithAI()
    #expect(model.phase == .reading)
    for _ in 0..<100 where model.phase == .reading {
      model.aiStatusChanged()
      try? await Task.sleep(for: .milliseconds(50))
    }
    #expect(model.phase == .review)
    #expect(model.draft.doseG == 18)
    #expect(model.draft.needsCheck(.grind))
    #expect(await stub.calls == 1)
    #expect(try context.fetch(FetchDescriptor<Brew>()).isEmpty)
    #expect(!model.canSave)
  }

  @Test func withoutAKeyNothingIsSentAndTheReasonIsShown() async throws {
    let cleanup = chooseAI()
    defer { cleanup() }
    let context = try make()
    let (model, stub) = aiModel(context, body: "{}", key: nil)
    await model.choose(photoData: PaperSample.page())
    model.readWithAI()
    for _ in 0..<100 where model.phase == .reading {
      model.aiStatusChanged()
      try? await Task.sleep(for: .milliseconds(50))
    }
    #expect(model.phase == .choose)
    #expect(model.errorMessage != nil)
    #expect(await stub.calls == 0)
  }

  @Test func aNonsenseAiAnswerIsDiscarded() async throws {
    let cleanup = chooseAI()
    defer { cleanup() }
    let context = try make()
    let (model, _) = aiModel(
      context, body: #"{"content":[{"type":"text","text":"{\"method\":\"V60\"}"}]}"#,
      key: "sk-test")
    await model.choose(photoData: PaperSample.page())
    model.readWithAI()
    for _ in 0..<100 where model.phase == .reading {
      model.aiStatusChanged()
      try? await Task.sleep(for: .milliseconds(50))
    }
    #expect(model.phase == .choose)
    #expect(model.draft.isEmpty)
  }
}

private actor PaperImportStubTransport: Transport {
  private let body: String
  private(set) var calls = 0
  init(_ body: String) { self.body = body }
  func send(_ request: URLRequest) async throws -> HTTPResult {
    calls += 1
    return HTTPResult(status: 200, body: Data(body.utf8))
  }
}
