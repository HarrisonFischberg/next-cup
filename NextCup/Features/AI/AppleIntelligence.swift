import Foundation
import FoundationModels
import NextCupKit

/// Apple's on-device model, the AI used when no key is set. Nothing leaves the iPhone, so it
/// needs no key and no disclosure. The model reads text, so a photo is first read with Vision.
enum AppleIntelligence {
  static let modelID = "on-device"
  /// The last underlying failure, for the QA harness; users see `AIError.unavailable`.
  nonisolated(unsafe) static var lastFailure: String?

  /// UI tests run without it, so their no-AI-yet paths stay the same on every Mac.
  static var isAvailable: Bool {
    !ProcessInfo.processInfo.arguments.contains("-inMemoryStore")
      && SystemLanguageModel.default.isAvailable
  }

  static func send(_ payload: AIRequestPayload) async throws -> AIResult {
    do {
      var prompt = payload.userText
      var lines: [String]?
      if let photo = payload.imageJPEG {
        lines = try await PaperScanner.lines(in: photo).map(\.text)
        let text = lines!.joined(separator: "\n")
        prompt +=
          "\n\nText read from the photo, top to bottom:\n" + (text.isEmpty ? "(none)" : text)
      }
      let schema = try JSONSerialization.data(
        withJSONObject: payload.schema.jsonObject, options: .sortedKeys)
      let session = LanguageModelSession(
        instructions: payload.system
          + "\n\nAnswer with one JSON object that matches this JSON Schema, and nothing else:\n"
          + String(decoding: schema, as: UTF8.self))
      let answer = try await session.respond(to: prompt).content
      // shortcut: the schema is checked after the fact, not guided; upgrade to
      // DynamicGenerationSchema if answers often come back invalid.
      guard let start = answer.firstIndex(of: "{"), let end = answer.lastIndex(of: "}"),
        let object = try? JSONSerialization.jsonObject(with: Data(answer[start...end].utf8)),
        payload.schema.validates(object),
        let json = try? JSONSerialization.data(
          withJSONObject: checked(object, lines: lines, schema: payload.schema),
          options: .sortedKeys)
      else { throw AIError.invalidResponse }
      return AIResult(json: json)
    } catch let error as AIError {
      throw error
    } catch is CancellationError {
      throw AIError.cancelled
    } catch {
      lastFailure = String(describing: error)
      throw AIError.unavailable(nil)
    }
  }

  /// The small on-device model invents roast dates, farms and roast levels and converts
  /// weights badly (measured in qa/), so for a photo those fields need the label text
  /// itself (`LabelEvidence`): no plain roast date on the label means no roast date.
  private static func checked(_ object: Any, lines: [String]?, schema: JSONSchema) -> Any {
    guard let lines, case .object(let properties) = schema, var answer = object as? [String: Any]
    else { return object }
    // Two different roast dates mean two bags; their lines interleave in OCR order, so any
    // answer would mix them. Fill nothing and let the user retake or type.
    if properties["roastDate"] != nil, LabelEvidence.roastDates(in: lines).count > 1 {
      return properties.mapValues { kind -> Any in
        switch kind {
        case .string: ""
        case .boolean: false
        default: 0
        }
      }
    }
    if properties["roastDate"] != nil {
      answer["roastDate"] = LabelEvidence.roastDate(in: lines) ?? ""
    }
    if properties["bagWeightGrams"] != nil {
      answer["bagWeightGrams"] = LabelEvidence.bagWeightGrams(in: lines) ?? 0
    }
    if properties["farm"] != nil, !LabelEvidence.namesFarm(in: lines) { answer["farm"] = "" }
    if properties["roastLevel"] != nil, !LabelEvidence.statesRoastLevel(in: lines) {
      answer["roastLevel"] = ""
    }
    return answer
  }
}
