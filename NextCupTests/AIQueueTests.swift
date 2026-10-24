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

@Suite(.serialized) @MainActor struct AIQueueTests {
  private static var containers: [ModelContainer] = []
  private let schema = JSONSchema.object(["field": .string(allowed: ["grind"])])
  private let valid = #"{"content":[{"type":"tool_use","input":{"field":"grind"}}]}"#

  private func payload() -> AIRequestPayload {
    AIRequestPayload(system: "s", userText: "u", schemaName: "suggest", schema: schema)
  }

  private func make(
    _ responses: [Result<HTTPResult, Error>], key: String? = "sk-test"
  ) throws -> (AIQueue, StubTransport, ModelContext) {
    // A dropped container crashes the test host, so keep every one alive.
    let container = try NextCupContainer.make(inMemory: true)
    Self.containers.append(container)
    let context = container.mainContext
    let stub = StubTransport(responses)
    let client = AIClient(
      transport: stub, key: { _ in key }, disclosureAccepted: { true }, sleep: { _ in })
    return (AIQueue(context: context, client: client), stub, context)
  }

  private func ok(_ body: String) -> Result<HTTPResult, Error> {
    .success(HTTPResult(status: 200, body: Data(body.utf8)))
  }

  private func enqueue(_ queue: AIQueue) throws -> AIRequest {
    try queue.enqueue(payload(), feature: .diagnosis, provider: .anthropic, modelID: "m")
  }

  @Test func sendsAndStoresTheResult() async throws {
    let (queue, stub, _) = try make([ok(valid)])
    let request = try enqueue(queue)
    await queue.waitForIdle()
    #expect(request.status == .done)
    #expect(request.attempts == 1)
    #expect(request.resultJSON.map { String(decoding: $0, as: UTF8.self) } == #"{"field":"grind"}"#)
    #expect(await stub.count == 1)
  }

  @Test func offlineStaysQueuedThenSendsWhenBack() async throws {
    let (queue, stub, _) = try make([ok(valid)])
    queue.setOnline(false)
    let request = try enqueue(queue)
    await queue.waitForIdle()
    #expect(request.status == .queued)
    #expect(await stub.count == 0)
    queue.setOnline(true)
    await queue.waitForIdle()
    #expect(request.status == .done)
  }

  @Test func offlineCanBeCancelled() async throws {
    let (queue, stub, _) = try make([ok(valid)])
    queue.setOnline(false)
    let request = try enqueue(queue)
    queue.cancel(request)
    queue.setOnline(true)
    await queue.waitForIdle()
    #expect(request.status == .cancelled)
    #expect(await stub.count == 0)
  }

  @Test func transportDroppingOutKeepsItQueued() async throws {
    let (queue, _, _) = try make([.failure(URLError(.notConnectedToInternet))])
    let request = try enqueue(queue)
    await queue.waitForIdle()
    #expect(request.status == .queued)
    #expect(request.errorMessage == AIError.offline.errorDescription)
  }

  @Test func invalidJSONFailsAndCreatesNoSuggestion() async throws {
    let (queue, _, context) = try make([
      ok(#"{"content":[{"type":"text","text":"just grind finer"}]}"#)
    ])
    let request = try enqueue(queue)
    await queue.waitForIdle()
    #expect(request.status == .failed)
    #expect(request.resultJSON == nil)
    #expect(request.errorMessage == AIError.invalidResponse.errorDescription)
    #expect(try context.fetch(FetchDescriptor<Suggestion>()).isEmpty)
  }

  @Test func missingKeyFailsWithoutAnyCall() async throws {
    let (queue, stub, _) = try make([ok(valid)], key: nil)
    let request = try enqueue(queue)
    await queue.waitForIdle()
    #expect(request.status == .failed)
    #expect(request.errorMessage == AIError.noKey.errorDescription)
    #expect(await stub.count == 0)
  }

  @Test func failedRequestCanBeRetried() async throws {
    let (queue, _, _) = try make([.success(HTTPResult(status: 401, body: Data())), ok(valid)])
    let request = try enqueue(queue)
    await queue.waitForIdle()
    #expect(request.status == .failed)
    queue.retry(request)
    await queue.waitForIdle()
    #expect(request.status == .done)
    #expect(request.attempts == 2)
  }

  @Test func payloadSurvivesStorageWithItsImageAsAttachment() throws {
    let (queue, _, _) = try make([])
    queue.setOnline(false)
    var withImage = payload()
    withImage.imageJPEG = Data([7, 7])
    let request = try queue.enqueue(
      withImage, feature: .bagRecognition, provider: .openAI, modelID: "m")
    #expect(request.attachment == Data([7, 7]))
    let stored = try JSONDecoder().decode(AIRequestPayload.self, from: request.payloadJSON)
    #expect(stored.schema == schema)
    #expect(!String(decoding: request.payloadJSON, as: UTF8.self).contains("imageJPEG"))
  }
}
