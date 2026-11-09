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
      var read: [PaperLine] = []
      if let photo = payload.imageJPEG {
        read = try await PaperScanner.lines(in: photo)
        lines = read.map(\.text)
        // A bag's brand and coffee name are its biggest type; plain text loses that.
        let text =
          (payload.schemaName == BagRecognition.schemaName
          ? BagRecognition.sized(read) : lines!).joined(separator: "\n")
        prompt +=
          "\n\nText read from the photo, top to bottom:\n" + (text.isEmpty ? "(none)" : text)
      }
      // Guided generation: the model fills the schema's exact keys and allowed values, which
      // the small model otherwise often gets wrong (missing keys, invented enum values).
      let schema = try GenerationSchema(
        root: guided(payload.schema, name: payload.schemaName), dependencies: [])
      let session = LanguageModelSession(instructions: payload.system)
      let answer = try await session.respond(to: prompt, schema: schema).content.jsonString
      guard var object = try? JSONSerialization.jsonObject(with: Data(answer.utf8)),
        payload.schema.validates(object)
      else { throw AIError.invalidResponse }
      if payload.schemaName == BagRecognition.schemaName, var bag = object as? [String: Any] {
        BagRecognition.fixName(&bag, from: read)
        // The small model often skips notes and roast that the label prints plainly.
        let text = read.map(\.text)
        if (bag["flavorNotes"] as? String ?? "").isEmpty {
          bag["flavorNotes"] = BagRecognition.flavorNotes(in: text, taxonomy: ExploreModel.taxonomy)
        }
        if (bag["roastLevel"] as? String ?? "").isEmpty,
          let level = BagRecognition.roastLevel(in: text)
        {
          bag["roastLevel"] = level.rawValue
        }
        object = bag
      }
      guard
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

  /// The app's schema as Foundation Models' guide. Nested objects need unique names.
  static func guided(_ schema: JSONSchema, name: String) -> DynamicGenerationSchema {
    switch schema {
    case .object(let properties):
      return DynamicGenerationSchema(
        name: name,
        properties: properties.keys.sorted().map {
          .init(name: $0, schema: guided(properties[$0]!, name: "\(name)_\($0)"))
        })
    case .array(let items):
      return DynamicGenerationSchema(arrayOf: guided(items, name: "\(name)_item"))
    case .string(let allowed):
      guard let allowed else { return DynamicGenerationSchema(type: String.self) }
      return DynamicGenerationSchema(name: name, anyOf: allowed)
    case .number: return DynamicGenerationSchema(type: Double.self)
    case .integer: return DynamicGenerationSchema(type: Int.self)
    case .boolean: return DynamicGenerationSchema(type: Bool.self)
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
