import Foundation
import FoundationModels
import NextCupKit

/// Apple's on-device model, the AI used when no key is set. Nothing leaves the iPhone, so it
/// needs no key and no disclosure. The model reads text, so a photo is first read with Vision.
enum AppleIntelligence {
  static let modelID = "on-device"

  /// UI tests run without it, so their no-AI-yet paths stay the same on every Mac.
  static var isAvailable: Bool {
    !ProcessInfo.processInfo.arguments.contains("-inMemoryStore")
      && SystemLanguageModel.default.isAvailable
  }

  static func send(_ payload: AIRequestPayload) async throws -> AIResult {
    do {
      var prompt = payload.userText
      if let photo = payload.imageJPEG {
        let text = try await PaperScanner.lines(in: photo).map(\.text).joined(separator: "\n")
        prompt += "\n\nText read from the photo:\n" + (text.isEmpty ? "(none)" : text)
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
        let json = try? JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
      else { throw AIError.invalidResponse }
      return AIResult(json: json)
    } catch let error as AIError {
      throw error
    } catch is CancellationError {
      throw AIError.cancelled
    } catch {
      throw AIError.unavailable(nil)
    }
  }
}
