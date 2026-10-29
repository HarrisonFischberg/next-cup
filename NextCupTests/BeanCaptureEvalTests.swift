import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

/// Settings for the bean-capture evaluation, passed by `qa/run-eval.sh` as `TEST_RUNNER_QA_*`
/// (xcodebuild hands them to this process without the prefix). Without `QA_ROOT` the
/// suite shows as skipped, so ordinary test runs never touch the network.
enum QAEnv {
  static let env = ProcessInfo.processInfo.environment
  static var root: URL? { env["QA_ROOT"].map { URL(fileURLWithPath: $0) } }
  static var providers: [String] {
    (env["QA_PROVIDERS"] ?? "apple").split(separator: ",").map(String.init)
  }
  static var model: String { env["QA_MODEL"] ?? "claude-opus-5-5" }
  static var maxRequests: Int { Int(env["QA_MAX_REQUESTS"] ?? "") ?? 40 }
  static var maxUSD: Double { Double(env["QA_MAX_USD"] ?? "") ?? 3 }
  static var repeats: Int { Int(env["QA_REPEAT"] ?? "") ?? 1 }
  static var split: String? { env["QA_SPLIT"].flatMap { $0.isEmpty ? nil : $0 } }
  static var ids: Set<String>? {
    env["QA_IDS"].flatMap { $0.isEmpty ? nil : Set($0.split(separator: ",").map(String.init)) }
  }
  /// $ per million input / output tokens, for the spend estimate and the budget stop.
  static var price: (input: Double, output: Double) {
    (Double(env["QA_PRICE_IN"] ?? "") ?? 4, Double(env["QA_PRICE_OUT"] ?? "") ?? 20)
  }

  /// Reads ANTHROPIC_API_KEY from the git-ignored credentials file. The key is only
  /// handed to the transport; it is never printed, recorded or written anywhere.
  static func anthropicKey() -> String? {
    guard let path = env["QA_ENV_FILE"],
      let text = try? String(contentsOfFile: path, encoding: .utf8)
    else { return nil }
    for line in text.split(whereSeparator: \.isNewline) {
      let parts = line.split(separator: "=", maxSplits: 1).map {
        $0.trimmingCharacters(in: .whitespaces)
      }
      if parts.count == 2, parts[0] == "ANTHROPIC_API_KEY", !parts[1].isEmpty {
        return parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
      }
    }
    return nil
  }
}

/// Wraps the app's own transport to time each call and keep the message id and token
/// usage from the answer. Headers (where the key lives) are never read.
actor RecordingTransport: Transport {
  struct Call: Sendable {
    var status: Int
    var ms: Int
    var messageID: String?
    var inputTokens: Int
    var outputTokens: Int
  }
  private let base = URLSessionTransport()
  private(set) var calls: [Call] = []

  func send(_ request: URLRequest) async throws -> HTTPResult {
    let start = Date()
    let result = try await base.send(request)
    let root = (try? JSONSerialization.jsonObject(with: result.body)) as? [String: Any]
    let usage = root?["usage"] as? [String: Any]
    calls.append(
      Call(
        status: result.status, ms: Int(Date().timeIntervalSince(start) * 1000),
        messageID: root?["id"] as? String,
        inputTokens: usage?["input_tokens"] as? Int ?? 0,
        outputTokens: usage?["output_tokens"] as? Int ?? 0))
    return result
  }

  func drain() -> [Call] {
    defer { calls = [] }
    return calls
  }
}

/// Runs fixture photos through the production pipeline: PhotoSanitizer → BagRecognition
/// payload → AIClient (Anthropic) or AppleIntelligence (Vision OCR + on-device model) →
/// schema check → BagRecognition.draft. Results go to `QA_ROOT/results/*.jsonl` for
/// `qa/tools/score.py`; nothing here decides what is correct.
@MainActor
@Suite("Bean capture eval (live)", .serialized, .enabled(if: QAEnv.root != nil))
struct BeanCaptureEvalTests {
  private static var containers: [ModelContainer] = []

  struct Fixture: Decodable {
    var id: String
    var file: String
    var split: String
  }

  private func fixtures() throws -> [Fixture] {
    struct Manifest: Decodable { var fixtures: [Fixture] }
    let data = try Data(contentsOf: QAEnv.root!.appending(path: "fixtures/manifest.json"))
    return try JSONDecoder().decode(Manifest.self, from: data).fixtures.filter {
      (QAEnv.split == nil || $0.split == QAEnv.split) && (QAEnv.ids?.contains($0.id) ?? true)
    }
  }

  private static let day: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  /// The fields exactly as the bean editor would receive them.
  private func record(_ fields: BeanFields) -> [String: Any] {
    [
      "name": fields.name, "roaster": fields.roasterName, "originCountry": fields.originCountry,
      "region": fields.region, "farm": fields.farm, "process": fields.process,
      "varietal": fields.varietal, "roastLevel": fields.roastLevel?.rawValue ?? "",
      "roastDate": fields.roastDate.map(Self.day.string) ?? "",
      "bagWeightGrams": fields.bagWeightG ?? 0,
      "flavorNotes": BeanFields.notes(from: fields.flavorNotes), "isDecaf": fields.isDecaf,
    ]
  }

  private func draft(from json: Data) throws -> BeanFields {
    let container = try NextCupContainer.make(inMemory: true)
    Self.containers.append(container)
    let request = AIRequest()
    request.feature = .bagRecognition
    request.status = .done
    request.resultJSON = json
    container.mainContext.insert(request)
    return try BagRecognition.draft(from: request).get()
  }

  @Test(.enabled(if: QAEnv.providers.contains("anthropic")))
  func anthropicKeyWorksAndModelTakesImages() async throws {
    let key = try #require(QAEnv.anthropicKey(), "ANTHROPIC_API_KEY missing from QA_ENV_FILE")
    let client = AIClient(
      transport: URLSessionTransport(), key: { _ in key }, disclosureAccepted: { _ in true })
    let models = try await client.models(.anthropic)
    try write(
      "auth",
      [["authenticated": true, "model": QAEnv.model, "listed": models.contains(QAEnv.model)]])
    #expect(models.contains(QAEnv.model), "the configured model is not offered to this key")
  }

  @Test func runFixtures() async throws {
    let root = QAEnv.root!
    var lines: [[String: Any]] = []
    var spent = 0.0
    var sent = 0
    let transport = RecordingTransport()
    let key = QAEnv.anthropicKey()
    let client = AIClient(
      transport: transport, key: { _ in key }, disclosureAccepted: { _ in true })
    let started = ISO8601DateFormatter().string(from: Date())

    for fixture in try fixtures() {
      let raw = try Data(contentsOf: root.appending(path: "fixtures/\(fixture.file)"))
      guard let photo = PhotoSanitizer.sanitized(raw) else {
        lines.append(["fixture": fixture.id, "error": "photo could not be decoded"])
        continue
      }
      let payload = BagRecognition.payload(photo: photo, feature: .bagRecognition)
      for provider in QAEnv.providers {
        for run in 1...QAEnv.repeats {
          var line: [String: Any] = [
            "fixture": fixture.id, "provider": provider, "run": run, "started": started,
            "imageAttached": payload.imageJPEG != nil, "imageBytes": photo.count,
          ]
          let start = Date()
          do {
            let result: AIResult
            if provider == "anthropic" {
              guard sent < QAEnv.maxRequests, spent < QAEnv.maxUSD else {
                line["status"] = "skipped-budget"
                lines.append(line)
                continue
              }
              sent += 1
              line["model"] = QAEnv.model
              result = try await client.send(payload, provider: .anthropic, model: QAEnv.model)
            } else {
              line["model"] = AppleIntelligence.modelID
              line["ocr"] = try await PaperScanner.lines(in: photo).map(\.text)
              result = try await AppleIntelligence.send(payload)
            }
            line["answer"] = try JSONSerialization.jsonObject(with: result.json)
            line["fields"] = record(try draft(from: result.json))
            line["status"] = "ok"
          } catch {
            line["status"] = "error"
            line["error"] = String(describing: error)
            if provider == "apple", let cause = AppleIntelligence.lastFailure {
              line["cause"] = cause
              AppleIntelligence.lastFailure = nil
            }
          }
          line["ms"] = Int(Date().timeIntervalSince(start) * 1000)
          let calls = await transport.drain()
          if !calls.isEmpty {
            let input = calls.reduce(0) { $0 + $1.inputTokens }
            let output = calls.reduce(0) { $0 + $1.outputTokens }
            let cost =
              Double(input) / 1e6 * QAEnv.price.input + Double(output) / 1e6 * QAEnv.price.output
            spent += cost
            line["attempts"] = calls.count
            line["httpStatus"] = calls.map(\.status)
            line["messageID"] = calls.last?.messageID ?? ""
            line["inputTokens"] = input
            line["outputTokens"] = output
            line["estUSD"] = cost
          }
          lines.append(line)
        }
      }
    }
    let kind = QAEnv.repeats > 1 ? "repeat" : "run"
    try write("\(kind)-\(QAEnv.providers.joined(separator: "+"))", lines)
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
