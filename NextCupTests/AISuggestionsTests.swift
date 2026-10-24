import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("AI suggestions")
struct AISuggestionsTests {
  private static var containers: [ModelContainer] = []

  private func make() throws -> ModelContext {
    // A dropped container crashes the test host, so keep every one alive.
    let container = try NextCupContainer.make(inMemory: true)
    Self.containers.append(container)
    return container.mainContext
  }

  private func brew(in context: ModelContext, daysAgo: Int = 0) -> Brew {
    let brew = Brew(date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!)
    brew.grindSetting = "20"
    brew.waterG = 250
    brew.tempC = 94
    brew.verdict = .sour
    context.insert(brew)
    return brew
  }

  private func done(
    _ json: String, feature: AIFeature = .diagnosis, brew: Brew?, in context: ModelContext
  ) -> AIRequest {
    let request = AIRequest()
    request.feature = feature
    request.modelID = "model-x"
    request.status = .done
    request.resultJSON = Data(json.utf8)
    context.insert(request)
    request.brew = brew
    return request
  }

  private let grind19 =
    #"{"field":"grind","toValue":"19","rationale":"Sour cups need more extraction."}"#

  @Test func diagnosisBecomesAProposedSuggestionWithSourceBrewAndModel() throws {
    let context = try make()
    let source = brew(in: context)
    let request = done(grind19, brew: source, in: context)
    let suggestion = try AISuggestions.ingest(request, in: context).get()
    #expect(suggestion.source == .ai)
    #expect(suggestion.state == .proposed)
    #expect(suggestion.field == .grind)
    #expect(suggestion.fromValue == "20")
    #expect(suggestion.toValue == "19")
    #expect(suggestion.modelID == "model-x")
    #expect(suggestion.sourceBrew?.id == source.id)
    #expect(source.suggestionsMade?.count == 1)
  }

  @Test func insightsUseTheSameFlowAndShowOnTheNextBrew() throws {
    let context = try make()
    let source = brew(in: context)
    let request = done(
      #"{"field":"temperature","toValue":"96","rationale":"Hotter water lifted the last three."}"#,
      feature: .insights, brew: source, in: context)
    let suggestion = try AISuggestions.ingest(request, in: context).get()
    #expect(suggestion.fromValue == "94")
    let all = try context.fetch(FetchDescriptor<Suggestion>())
    let match = SuggestionService.match(
      in: all, beanIDs: [], methodID: nil, excluding: UUID())
    #expect(match?.id == suggestion.id)
  }

  @Test func ingestingTwiceKeepsOneCard() throws {
    let context = try make()
    let request = done(grind19, brew: brew(in: context), in: context)
    let first = try AISuggestions.ingest(request, in: context).get()
    let second = try AISuggestions.ingest(request, in: context).get()
    #expect(first.id == second.id)
    #expect(try context.fetch(FetchDescriptor<Suggestion>()).count == 1)
  }

  @Test func unusableAnswersStoreNothing() throws {
    let context = try make()
    let source = brew(in: context)
    let bad = [
      #"{"field":"grind"}"#,
      #"{"field":"dose","toValue":"15","rationale":"r"}"#,
      #"{"field":"water","toValue":"lots","rationale":"r"}"#,
      #"{"field":"time","toValue":"-5","rationale":"r"}"#,
      #"{"field":"grind","toValue":"  ","rationale":"r"}"#,
      "just grind finer",
    ]
    for json in bad {
      let request = done(json, brew: source, in: context)
      #expect(AISuggestions.ingest(request, in: context) == .failure(.invalidResponse))
    }
    #expect(try context.fetch(FetchDescriptor<Suggestion>()).isEmpty)
  }

  @Test func requestWithoutABrewOrOtherFeatureStoresNothing() throws {
    let context = try make()
    let noBrew = done(grind19, brew: nil, in: context)
    let other = done(grind19, feature: .paperImport, brew: brew(in: context), in: context)
    #expect(AISuggestions.ingest(noBrew, in: context) == .failure(.invalidResponse))
    #expect(AISuggestions.ingest(other, in: context) == .failure(.invalidResponse))
    #expect(try context.fetch(FetchDescriptor<Suggestion>()).isEmpty)
  }

  @Test func newerAISuggestionDismissesTheStaleOne() throws {
    let context = try make()
    let older = brew(in: context, daysAgo: 3)
    let newer = brew(in: context)
    let first = try AISuggestions.ingest(done(grind19, brew: older, in: context), in: context).get()
    let second = try AISuggestions.ingest(done(grind19, brew: newer, in: context), in: context)
      .get()
    #expect(first.state == .dismissed)
    #expect(second.state == .proposed)
  }

  @Test func payloadCarriesTheSchemaAndOnlyBrewFacts() {
    let context = try! make()
    let source = brew(in: context)
    source.notes = "tangy"
    let payload = AISuggestions.payload(diagnosing: source)
    #expect(payload.schema == AISuggestions.schema)
    #expect(payload.imageJPEG == nil)
    #expect(payload.userText.contains("grind 20"))
    #expect(payload.userText.contains("tasted sour"))
    #expect(payload.userText.contains("notes: tangy"))
    let insights = AISuggestions.payload(insightsFrom: [source])
    #expect(insights.userText.contains("newest first"))
  }

  @Test func queueIngestsAfterAFinishedSend() async throws {
    let context = try make()
    let source = brew(in: context)
    let stub = StubTransport([
      .success(
        HTTPResult(
          status: 200,
          body: Data(
            #"{"content":[{"type":"tool_use","input":{"field":"grind","toValue":"19","rationale":"r"}}]}"#
              .utf8)))
    ])
    let client = AIClient(
      transport: stub, key: { _ in "sk-test" }, disclosureAccepted: { true }, sleep: { _ in })
    let queue = AIQueue(context: context, client: client)
    queue.onDone = { AISuggestions.ingest($0, in: context) }
    try queue.enqueue(
      AISuggestions.payload(diagnosing: source), feature: .diagnosis, provider: .anthropic,
      modelID: "m", brew: source)
    await queue.waitForIdle()
    let stored = try context.fetch(FetchDescriptor<Suggestion>())
    #expect(stored.count == 1)
    #expect(stored.first?.modelID == "m")
  }
}

private actor StubTransport: Transport {
  private var responses: [Result<HTTPResult, Error>]
  init(_ responses: [Result<HTTPResult, Error>]) { self.responses = responses }
  func send(_ request: URLRequest) async throws -> HTTPResult {
    try responses.removeFirst().get()
  }
}
