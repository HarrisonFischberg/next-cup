import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

private actor StubTransport: Transport {
  private var responses: [Result<HTTPResult, Error>]
  private(set) var count = 0

  init(_ responses: [Result<HTTPResult, Error>]) { self.responses = responses }

  func send(_ request: URLRequest) async throws -> HTTPResult {
    count += 1
    return try responses.removeFirst().get()
  }
}

@Suite("Ask AI", .serialized) @MainActor struct AIAskModelTests {
  private static var containers: [ModelContainer] = []
  private let answer = HTTPResult(
    status: 200,
    body: Data(
      #"{"content":[{"type":"tool_use","input":{"field":"grind","toValue":"19","rationale":"Sour cups need more extraction."}}]}"#
        .utf8))

  private struct Rig {
    let model: AIAskModel
    let queue: AIQueue
    let stub: StubTransport
    let context: ModelContext
    let source: Brew
  }

  /// A model whose preferences, key check and transport are all stand-ins.
  private func rig(
    feature: AIFeature = .diagnosis, chosen: Bool = true, key: Bool = true,
    disclosed: Bool = true, responses: [Result<HTTPResult, Error>] = [], brewCount: Int = 1
  ) throws -> Rig {
    // A dropped container crashes the test host, so keep every one alive.
    let container = try NextCupContainer.make(inMemory: true)
    Self.containers.append(container)
    let context = container.mainContext
    let defaults = UserDefaults(suiteName: "ai-ask-\(UUID().uuidString)")!
    let preferences = AIPreferences(defaults: defaults)
    if chosen { preferences.setChoice(.anthropic, model: "model-x", for: feature) }
    if disclosed { preferences.acceptDisclosure(for: .anthropic) }

    let brews = (0..<brewCount).map { day in
      let brew = Brew(date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!)
      brew.grindSetting = "20"
      brew.waterG = 250
      brew.verdict = .sour
      brew.notes = "tangy \(day)"
      context.insert(brew)
      return brew
    }
    let stub = StubTransport(responses)
    let client = AIClient(
      transport: stub, key: { _ in "sk-test" }, disclosureAccepted: { _ in true }, sleep: { _ in })
    let queue = AIQueue(context: context, client: client)
    let model = AIAskModel(
      feature: feature, brews: brews, context: context, preferences: preferences,
      hasKey: { _ in key }, makeQueue: { _ in queue })
    return Rig(model: model, queue: queue, stub: stub, context: context, source: brews[0])
  }

  private func requests(_ context: ModelContext) throws -> [AIRequest] {
    try context.fetch(FetchDescriptor<AIRequest>())
  }

  @Test func nothingIsSentWithoutAKey() async throws {
    let rig = try rig(key: false, responses: [.success(answer)])
    #expect(rig.model.readiness == .needsKey(.anthropic))
    rig.model.send()
    await rig.queue.waitForIdle()
    #expect(rig.model.request == nil)
    #expect(try requests(rig.context).isEmpty)
    #expect(await rig.stub.count == 0)
  }

  @Test func nothingIsSentWithoutAChosenModel() async throws {
    let rig = try rig(chosen: false, responses: [.success(answer)])
    #expect(rig.model.readiness == .needsChoice)
    rig.model.send()
    await rig.queue.waitForIdle()
    #expect(try requests(rig.context).isEmpty)
    #expect(await rig.stub.count == 0)
  }

  @Test func nothingIsSentUntilThisProviderIsDisclosed() async throws {
    let rig = try rig(disclosed: false, responses: [.success(answer)])
    #expect(rig.model.readiness == .needsDisclosure(.anthropic, modelID: "model-x"))
    rig.model.send()
    await rig.queue.waitForIdle()
    #expect(try requests(rig.context).isEmpty)
    #expect(await rig.stub.count == 0)
    rig.model.acceptDisclosure(for: .anthropic)
    #expect(rig.model.readiness == .ready(.anthropic, modelID: "model-x"))
  }

  @Test func theTapSendsExactlyThePreviewedText() async throws {
    let rig = try rig(responses: [.success(answer)])
    #expect(rig.model.payload.userText == AISuggestions.payload(diagnosing: rig.source).userText)
    #expect(rig.model.payload.userText.contains("tangy 0"))
    #expect(await rig.stub.count == 0, "building the preview sends nothing")
    rig.model.send()
    let queued = try #require(try requests(rig.context).first)
    let stored = try JSONDecoder().decode(AIRequestPayload.self, from: queued.payloadJSON)
    #expect(stored.userText == rig.model.payload.userText)
    await rig.queue.waitForIdle()
    #expect(await rig.stub.count == 1)
  }

  @Test func theAnswerBecomesASuggestionStoredWithTheBrew() async throws {
    let rig = try rig(responses: [.success(answer)])
    rig.model.send()
    await rig.queue.waitForIdle()
    rig.model.statusChanged()
    let suggestion = try #require(rig.model.suggestion)
    #expect(suggestion.source == .ai)
    #expect(suggestion.state == .proposed)
    #expect(suggestion.toValue == "19")
    #expect(suggestion.modelID == "model-x")
    #expect(suggestion.sourceBrew?.id == rig.source.id)
    #expect(rig.model.errorMessage == nil)
  }

  @Test func dismissingHasAnUndo() async throws {
    let rig = try rig(responses: [.success(answer)])
    rig.model.send()
    await rig.queue.waitForIdle()
    rig.model.statusChanged()
    let suggestion = try #require(rig.model.suggestion)
    rig.model.setDismissed(true)
    #expect(suggestion.state == .dismissed)
    rig.model.setDismissed(false)
    #expect(suggestion.state == .proposed)
  }

  @Test func insightsSendUpToEightBrewsNewestFirst() throws {
    let rig = try rig(feature: .insights, brewCount: 10)
    let lines = rig.model.payload.userText.split(separator: "\n").filter { $0.hasPrefix("- ") }
    #expect(lines.count == 8)
    #expect(lines.first?.contains("tangy 0") == true)
    #expect(!rig.model.payload.userText.contains("tangy 9"))
  }

  @Test func aFailureShowsItsReasonAndTryAgainSends() async throws {
    let rig = try rig(responses: [
      .success(HTTPResult(status: 401, body: Data())), .success(answer),
    ])
    rig.model.send()
    await rig.queue.waitForIdle()
    rig.model.statusChanged()
    #expect(rig.model.errorMessage != nil)
    #expect(rig.model.suggestion == nil)

    rig.model.retry()
    #expect(rig.model.errorMessage == nil)
    await rig.queue.waitForIdle()
    rig.model.statusChanged()
    #expect(rig.model.suggestion != nil)
    #expect(await rig.stub.count == 2)
  }

  @Test func offlineWaitsVisiblyAndCancelSendsNothing() async throws {
    let rig = try rig(responses: [.success(answer)])
    rig.queue.setOnline(false)
    rig.model.send()
    #expect(rig.model.isWorking)
    #expect(rig.model.isWaitingForConnection)
    let request = try #require(rig.model.request)
    rig.model.cancel()
    #expect(request.status == .cancelled)
    #expect(request.payloadJSON.isEmpty)
    rig.queue.setOnline(true)
    await rig.queue.waitForIdle()
    #expect(rig.model.request == nil)
    #expect(await rig.stub.count == 0)
  }

  @Test func closingTheSheetCancelsWhatIsStillQueued() async throws {
    let rig = try rig(responses: [.success(answer)])
    rig.queue.setOnline(false)
    rig.model.send()
    let request = try #require(rig.model.request)
    rig.model.leave()
    rig.queue.setOnline(true)
    await rig.queue.waitForIdle()
    #expect(request.status == .cancelled)
    #expect(await rig.stub.count == 0)
  }
}
