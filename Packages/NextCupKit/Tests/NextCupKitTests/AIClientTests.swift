import Foundation
import Testing

@testable import NextCupKit

actor StubTransport: Transport {
  private var responses: [Result<HTTPResult, Error>]
  private(set) var requests: [URLRequest] = []

  init(_ responses: [Result<HTTPResult, Error>]) { self.responses = responses }

  func send(_ request: URLRequest) async throws -> HTTPResult {
    requests.append(request)
    return try responses.removeFirst().get()
  }
}

@Suite("AIClient")
struct AIClientTests {
  private let schema = JSONSchema.object([
    "field": .string(allowed: ["grind", "temperature"]), "delta": .integer,
  ])
  private let answer = #"{"field":"grind","delta":-2}"#

  private func payload() -> AIRequestPayload {
    AIRequestPayload(system: "s", userText: "u", schemaName: "suggest", schema: schema)
  }

  private func client(
    _ stub: StubTransport, key: String? = "sk-test",
    disclosed: Set<AIProviderKind> = [
      .anthropic, .openAI,
    ]
  ) -> AIClient {
    AIClient(
      transport: stub, key: { _ in key }, disclosureAccepted: { disclosed.contains($0) },
      sleep: { _ in })
  }

  private func ok(_ body: String) -> Result<HTTPResult, Error> {
    .success(HTTPResult(status: 200, body: Data(body.utf8)))
  }

  private func status(_ code: Int) -> Result<HTTPResult, Error> {
    .success(HTTPResult(status: code, body: Data()))
  }

  private func anthropicBody(_ text: String) -> String {
    let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
    return #"{"content":[{"type":"thinking","thinking":""},{"type":"text","text":"\#(escaped)"}]}"#
  }

  private var anthropicBody: String { anthropicBody(answer) }

  private func openAIBody(_ text: String) -> String {
    let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
    return
      #"{"output":[{"type":"message","content":[{"type":"output_text","text":"\#(escaped)"}]}]}"#
  }

  @Test func noKeyMeansNoCall() async {
    let stub = StubTransport([])
    await #expect(throws: AIError.noKey) {
      try await client(stub, key: nil).send(payload(), provider: .anthropic, model: "m")
    }
    await #expect(throws: AIError.noKey) {
      try await client(stub, key: "").send(payload(), provider: .openAI, model: "m")
    }
    #expect(await stub.requests.isEmpty)
  }

  @Test func noDisclosureMeansNoCall() async {
    let stub = StubTransport([])
    await #expect(throws: AIError.disclosureNotAccepted) {
      try await client(stub, disclosed: []).send(payload(), provider: .anthropic, model: "m")
    }
    #expect(await stub.requests.isEmpty)
  }

  @Test func disclosureForOneProviderDoesNotUnlockAnother() async {
    let stub = StubTransport([])
    await #expect(throws: AIError.disclosureNotAccepted) {
      try await client(stub, disclosed: [.anthropic]).send(
        payload(), provider: .openAI, model: "m")
    }
    #expect(await stub.requests.isEmpty)
  }

  @Test func anthropicRequestAndResult() async throws {
    let stub = StubTransport([ok(anthropicBody)])
    let image = Data([1, 2, 3])
    var withImage = payload()
    withImage.imageJPEG = image
    let result = try await client(stub).send(withImage, provider: .anthropic, model: "model-a")
    #expect(String(decoding: result.json, as: UTF8.self) == #"{"delta":-2,"field":"grind"}"#)
    let request = try #require(await stub.requests.first)
    #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
    #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-test")
    #expect(request.value(forHTTPHeaderField: "anthropic-version") != nil)
    #expect(request.timeoutInterval == 120)
    let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
    #expect(body.contains("\"model\":\"model-a\""))
    #expect(body.contains(image.base64EncodedString()))
    #expect(body.contains("\"json_schema\""))
    #expect(!body.contains("\"tool_choice\""), "current models refuse a forced tool")
    #expect(!body.contains("\"effort\""), "no effort unless one is chosen")
  }

  @Test func effortIsSentWhenChosen() async throws {
    let stub = StubTransport([ok(anthropicBody), ok(openAIBody(answer))])
    _ = try await client(stub).send(payload(), provider: .anthropic, model: "m", effort: "low")
    _ = try await client(stub).send(payload(), provider: .openAI, model: "m", effort: "high")
    let bodies = await stub.requests.map { String(decoding: $0.httpBody ?? Data(), as: UTF8.self) }
    #expect(bodies[0].contains(#""output_config":{"effort":"low""#))
    #expect(bodies[1].contains(#""reasoning":{"effort":"high"}"#))
  }

  @Test func modelsListChecksTheKey() async throws {
    let stub = StubTransport([
      ok(#"{"data":[{"id":"claude-a"},{"id":"claude-b"}]}"#),
      ok(#"{"data":[{"id":"gpt-5"},{"id":"tts-1"},{"id":"o4-mini"},{"id":"gpt-4o-audio"}]}"#),
      status(401),
    ])
    #expect(try await client(stub).models(.anthropic) == ["claude-a", "claude-b"])
    #expect(try await client(stub).models(.openAI) == ["o4-mini", "gpt-5"])
    await #expect(throws: AIError.keyRejected) { try await client(stub).models(.anthropic) }
  }

  @Test func openAIRequestAndResult() async throws {
    let stub = StubTransport([ok(openAIBody(answer))])
    let result = try await client(stub).send(payload(), provider: .openAI, model: "model-o")
    #expect(String(decoding: result.json, as: UTF8.self) == #"{"delta":-2,"field":"grind"}"#)
    let request = try #require(await stub.requests.first)
    #expect(request.url?.absoluteString == "https://api.openai.com/v1/responses")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
    let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
    #expect(body.contains("\"json_schema\""))
  }

  @Test func rejectedKeyStopsAtOnce() async {
    let stub = StubTransport([status(401), status(200)])
    await #expect(throws: AIError.keyRejected) {
      try await client(stub).send(payload(), provider: .anthropic, model: "m")
    }
    #expect(await stub.requests.count == 1)
  }

  @Test func retriesStopAtThree() async {
    let stub = StubTransport([status(429), status(529), status(500), ok(anthropicBody)])
    await #expect(throws: AIError.unavailable(500)) {
      try await client(stub).send(payload(), provider: .anthropic, model: "m")
    }
    #expect(await stub.requests.count == 3)
  }

  @Test func retryThenSucceed() async throws {
    let stub = StubTransport([status(429), ok(anthropicBody)])
    _ = try await client(stub).send(payload(), provider: .anthropic, model: "m")
    #expect(await stub.requests.count == 2)
  }

  @Test func backoffDoubles() async throws {
    let waits = Waits()
    let stub = StubTransport([status(500), status(500), ok(anthropicBody)])
    let client = AIClient(
      transport: stub, key: { _ in "k" }, disclosureAccepted: { _ in true },
      backoff: .seconds(1), sleep: { await waits.add($0) })
    _ = try await client.send(payload(), provider: .anthropic, model: "m")
    #expect(await waits.values == [.seconds(1), .seconds(2)])
  }

  @Test(arguments: [
    #"not json"#, #"{"content":[]}"#,
    #"{"content":[{"type":"text","text":"{\"field\":\"grind\"}"}]}"#,
    #"{"content":[{"type":"text","text":"{\"field\":\"water\",\"delta\":1}"}]}"#,
    #"{"content":[{"type":"text","text":"{\"field\":\"grind\",\"delta\":1.5}"}]}"#,
    #"{"content":[{"type":"text","text":"{\"field\":\"grind\",\"delta\":1,\"extra\":true}"}]}"#,
    #"{"content":[{"type":"text","text":"sure, grind finer"}]}"#,
  ])
  func invalidOutputIsDiscarded(body: String) async {
    let stub = StubTransport([ok(body), ok(anthropicBody)])
    await #expect(throws: AIError.invalidResponse) {
      try await client(stub).send(payload(), provider: .anthropic, model: "m")
    }
    #expect(await stub.requests.count == 1)
  }

  @Test func openAIOutputThatIsNotJSONIsDiscarded() async {
    let stub = StubTransport([ok(openAIBody("sure, lower the grind"))])
    await #expect(throws: AIError.invalidResponse) {
      try await client(stub).send(payload(), provider: .openAI, model: "m")
    }
  }

  @Test func offlineIsNotRetried() async {
    let stub = StubTransport([.failure(URLError(.notConnectedToInternet)), ok(anthropicBody)])
    await #expect(throws: AIError.offline) {
      try await client(stub).send(payload(), provider: .anthropic, model: "m")
    }
    #expect(await stub.requests.count == 1)
  }

  @Test func schemaDistinguishesBooleansFromNumbers() throws {
    let data = Data(#"{"a":true,"b":1}"#.utf8)
    let value = try JSONSerialization.jsonObject(with: data)
    #expect(JSONSchema.object(["a": .boolean, "b": .integer]).validates(value))
    #expect(!JSONSchema.object(["a": .integer, "b": .boolean]).validates(value))
  }

  @Test func payloadCodingOmitsTheImage() throws {
    var original = payload()
    original.imageJPEG = Data([9])
    let decoded = try JSONDecoder().decode(
      AIRequestPayload.self, from: JSONEncoder().encode(original))
    #expect(decoded.imageJPEG == nil)
    #expect(decoded.schema == original.schema)
  }
}

private actor Waits {
  private(set) var values: [Duration] = []
  func add(_ value: Duration) { values.append(value) }
}
