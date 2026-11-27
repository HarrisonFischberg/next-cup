import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

/// Runs the recipe requests in `qa/fixtures/recipes.json` through the production recipe AI:
/// the real payload builders (brewer size and `BrewReference` line included) → AIClient
/// (Anthropic) or AppleIntelligence → `RecipeReviewAI.parse` → `RecipeReviewAI.fit`. Each
/// line of `QA_ROOT/results/recipes-*.jsonl` says whether the first answer made a recipe,
/// whether its numbers and pours passed, and what came out after the one retry. The rules
/// that score an answer are the app's own; no model decides what is correct. Started by
/// `qa/run-eval.sh <providers> recipes`; otherwise the suite shows as skipped.
@MainActor
@Suite(
  "Recipe eval (live)", .serialized,
  .enabled(if: QAEnv.root != nil && QAEnv.env["QA_SUITE"] == "recipes"))
struct RecipeEvalTests {
  private static var containers: [ModelContainer] = []

  struct Fixture: Decodable {
    var id: String
    var mode: String
    var method: String
    var note: String
  }

  private func fixtures() throws -> [Fixture] {
    struct File: Decodable { var fixtures: [Fixture] }
    let data = try Data(contentsOf: QAEnv.root!.appending(path: "fixtures/recipes.json"))
    return try JSONDecoder().decode(File.self, from: data).fixtures.filter {
      QAEnv.ids?.contains($0.id) ?? true
    }
  }

  private func numbers(_ draft: RecipeDraft) -> [String: Any] {
    [
      "doseG": draft.doseG, "waterG": draft.waterG, "tempC": draft.tempC ?? 0,
      "totalTimeS": draft.totalTimeS ?? 0, "steps": draft.steps.count,
      "ratio": BrewReference.ratio(of: draft).map { ($0 * 10).rounded() / 10 } ?? 0,
    ]
  }

  @Test func everyRequestGetsARecipeThatPasses() async throws {
    let container = try NextCupContainer.make(inMemory: true)
    Self.containers.append(container)
    let store = Store(context: container.mainContext)
    let defaults = try #require(UserDefaults(suiteName: "RecipeEval.\(UUID().uuidString)"))
    _ = BuiltInSeeder(store: store, defaults: defaults).seed(try BuiltInContent(bundle: .main))
    let methods = try store.context.fetch(FetchDescriptor<BrewMethod>())
    let transport = RecordingTransport()
    let key = QAEnv.anthropicKey()
    let client = AIClient(
      transport: transport, key: { _ in key }, disclosureAccepted: { _ in true })
    var lines: [[String: Any]] = []
    var spent = 0.0

    for fixture in try fixtures() {
      let method = try #require(methods.first { $0.builtInKey == fixture.method }, "\(fixture.id)")
      let mode: RecipeReviewAI.Mode = fixture.mode == "create" ? .create : .improve
      let brewer = BrewerFit.current(method.builtInKey, defaults: defaults)
      var base = RecipeDraft()
      base.methodID = method.id
      if mode == .improve {
        base = try #require(BeanBrewAI.builtInDraft(for: method, store: store), "\(fixture.id)")
      }
      let sanity = RecipeReviewAI.Sanity(
        method: method, note: fixture.note, from: mode == .improve ? base : nil)
      let reference = sanity?.reference.promptLine()
      let payload =
        mode == .create
        ? RecipeReviewAI.createPayload(
          methodName: method.name, style: RecipeFormat.title(method.style), note: fixture.note,
          brewer: brewer, reference: reference)
        : RecipeReviewAI.payload(
          base, methodName: method.name, note: fixture.note, brewer: brewer, reference: reference)

      for provider in QAEnv.providers {
        var line: [String: Any] = [
          "fixture": fixture.id, "provider": provider, "mode": fixture.mode,
          "method": fixture.method, "note": fixture.note,
        ]
        var asked = 0
        let send: (AIRequestPayload) async throws -> (answer: [String: Any], source: String) = {
          asked += 1
          let result =
            provider == "anthropic"
            ? try await client.send($0, provider: .anthropic, model: QAEnv.model)
            : try await AppleIntelligence.send($0)
          let answer = try JSONSerialization.jsonObject(with: result.json) as? [String: Any]
          return (answer ?? [:], provider)
        }
        let start = Date()
        if provider == "anthropic", lines.count >= QAEnv.maxRequests || spent >= QAEnv.maxUSD {
          line["status"] = "skipped-budget"
          lines.append(line)
          continue
        }
        do {
          let (answer, source) = try await send(payload)
          guard let first = RecipeReviewAI.parse(answer, base: base, source: source, mode: mode)
          else {
            line["status"] = "first-answer-not-a-recipe"
            line["answer"] = answer
            throw AIError.invalidResponse
          }
          line["first"] = numbers(first.draft)
          line["firstNumbers"] = sanity?.problem(first.draft) ?? "ok"
          line["firstFits"] = brewer?.problem(first.draft) ?? "ok"
          let final = try await RecipeReviewAI.fit(
            first, brewer: brewer, payload: payload, base: base, mode: mode, sanity: sanity,
            send: send)
          line["final"] = numbers(final.draft)
          line["status"] = "ok"
          #expect(sanity?.problem(final.draft) == nil || sanity?.strict == false)
          #expect(brewer?.problem(final.draft) == nil)
        } catch {
          if line["status"] == nil { line["status"] = "thrown-away" }
          line["error"] = String(describing: error)
          if provider == "apple", let cause = AppleIntelligence.lastFailure {
            line["cause"] = cause
            AppleIntelligence.lastFailure = nil
          }
        }
        line["asked"] = asked
        line["ms"] = Int(Date().timeIntervalSince(start) * 1000)
        let calls = await transport.drain()
        let cost = calls.reduce(0.0) {
          $0 + Double($1.inputTokens) / 1e6 * QAEnv.price.input
            + Double($1.outputTokens) / 1e6 * QAEnv.price.output
        }
        spent += cost
        if !calls.isEmpty { line["estUSD"] = cost }
        lines.append(line)
      }
    }
    try write("recipes-\(QAEnv.providers.joined(separator: "+"))", lines)
  }

  /// One web search kept to `RecipeReviewAI.researchSites`, to prove the provider takes the
  /// list and cites those sites. Costs up to 3 searches, so only with `QA_RESEARCH=1`.
  @Test(.enabled(if: QAEnv.providers.contains("anthropic") && QAEnv.env["QA_RESEARCH"] == "1"))
  func researchStaysOnTheSites() async throws {
    let key = try #require(QAEnv.anthropicKey(), "ANTHROPIC_API_KEY missing from QA_ENV_FILE")
    let transport = RecordingTransport()
    let client = AIClient(
      transport: transport, key: { _ in key }, disclosureAccepted: { _ in true })
    let found = try await client.research(
      RecipeReviewAI.researchQuestion(
        methodName: "Cone dripper", style: "Pour over", note: "one bright cup of a light roast",
        grinder: nil),
      system: RecipeReviewAI.researchSystem, provider: .anthropic, model: QAEnv.model,
      domains: RecipeReviewAI.researchSites)
    let calls = await transport.drain()
    let hosts = found.sources.compactMap { $0.url.host() }
    try write(
      "research-anthropic",
      [
        [
          "requests": calls.count, "httpStatus": calls.map(\.status), "hosts": hosts,
          "notes": found.notes,
        ]
      ])
    #expect(calls.count == 1, "the site list was refused and the open web was used instead")
    #expect(!hosts.isEmpty)
    for host in hosts {
      #expect(
        RecipeReviewAI.researchSites.contains { host == $0 || host.hasSuffix(".\($0)") }, "\(host)")
    }
  }

  private func write(_ name: String, _ lines: [[String: Any]]) throws {
    let dir = QAEnv.root!.appending(path: "results")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let text = try lines.map {
      String(
        decoding: try JSONSerialization.data(withJSONObject: $0, options: .sortedKeys),
        as: UTF8.self)
    }.joined(separator: "\n")
    try Data((text + "\n").utf8).write(to: dir.appending(path: "\(name).jsonl"))
  }
}
