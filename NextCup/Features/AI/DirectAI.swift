import Foundation
import NextCupKit

/// A one-off request answered while the user waits, outside the queue: the provider chosen
/// for brew diagnosis in Settings → AI when it has a key and its notice was accepted, else
/// Apple's on-device model. Callers ask a keyed provider only after a tap.
@MainActor
enum DirectAI {
  /// The provider and model that would answer; nil when neither a key nor Apple's model is there.
  static var route: (AIProvider, String)? {
    let preferences = AIPreferences()
    if let provider = preferences.provider(for: .diagnosis), provider.kind != nil,
      let model = preferences.modelID(for: .diagnosis), KeychainStore().hasKey(for: provider),
      preferences.hasAcceptedDisclosure(for: provider)
    {
      return (provider, model)
    }
    return AppleIntelligence.isAvailable ? (.apple, AppleIntelligence.modelID) : nil
  }

  /// The provider that would answer, when it is a keyed cloud provider; nil for Apple's model.
  static var cloudProviderTitle: String? {
    guard let (provider, _) = route, provider.kind != nil else { return nil }
    return provider.title
  }

  /// Sends one payload and returns the decoded answer with who gave it: "Anthropic",
  /// "OpenAI" or "On this iPhone".
  static func send(_ payload: AIRequestPayload) async throws -> (
    answer: [String: Any], source: String
  ) {
    guard let (provider, model) = route else { throw AIError.unavailable(nil) }
    let result: AIResult
    if let kind = provider.kind {
      let keychain = KeychainStore()
      let client = AIClient(
        transport: URLSessionTransport(),
        key: { _ in (try? keychain.key(for: provider)) ?? nil },
        disclosureAccepted: { _ in true })
      result = try await client.send(
        payload, provider: kind, model: model, effort: AIPreferences().effort)
    } else {
      result = try await AppleIntelligence.send(payload)
    }
    guard let answer = try JSONSerialization.jsonObject(with: result.json) as? [String: Any]
    else { throw AIError.invalidResponse }
    return (answer, provider == .apple ? "On this iPhone" : provider.title)
  }
}
