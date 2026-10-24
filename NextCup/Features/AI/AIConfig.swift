import Foundation
import Security

/// AI provider keys, held in the Keychain for this device only (blueprint §1).
/// One generic-password item per provider; `DataEraser` clears them on delete all.
struct KeychainStore: Sendable {
  var service = "app.rarecreatures.nextcup.ai"

  enum KeychainError: Error, LocalizedError, Equatable {
    case failed(OSStatus)
    var errorDescription: String? {
      switch self {
      case .failed(let status): "The Keychain refused the request (code \(status))."
      }
    }
  }

  private func query(_ provider: AIProvider) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword, kSecAttrService: service,
      kSecAttrAccount: provider.rawValue,
    ]
  }

  func key(for provider: AIProvider) throws -> String? {
    var request = query(provider)
    request[kSecReturnData] = true
    request[kSecMatchLimit] = kSecMatchLimitOne
    var result: CFTypeRef?
    switch SecItemCopyMatching(request as CFDictionary, &result) {
    case errSecSuccess: return (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
    case errSecItemNotFound: return nil
    case let status: throw KeychainError.failed(status)
    }
  }

  func hasKey(for provider: AIProvider) -> Bool { ((try? key(for: provider)) ?? nil) != nil }

  func setKey(_ key: String, for provider: AIProvider) throws {
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return try removeKey(for: provider) }
    let attributes: [CFString: Any] = [
      kSecValueData: Data(trimmed.utf8),
      kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]
    var status = SecItemUpdate(query(provider) as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      status = SecItemAdd(query(provider).merging(attributes) { $1 } as CFDictionary, nil)
    }
    guard status == errSecSuccess else { throw KeychainError.failed(status) }
  }

  func removeKey(for provider: AIProvider) throws {
    let status = SecItemDelete(query(provider) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.failed(status)
    }
  }
}

/// Non-secret AI preferences (blueprint §5): disclosure version accepted and
/// the provider and model chosen for each feature. Never holds a key.
struct AIPreferences {
  /// Bump when the disclosure text changes so it is shown again.
  static let disclosureVersion = 1
  static let disclosureKey = "ai.disclosure.version"

  var defaults: UserDefaults = .standard

  var hasAcceptedDisclosure: Bool {
    defaults.integer(forKey: Self.disclosureKey) >= Self.disclosureVersion
  }

  func acceptDisclosure() { defaults.set(Self.disclosureVersion, forKey: Self.disclosureKey) }

  static func providerKey(_ feature: AIFeature) -> String { "ai.provider.\(feature.rawValue)" }
  static func modelKey(_ feature: AIFeature) -> String { "ai.model.\(feature.rawValue)" }

  /// `nil` until the user picks one; nothing is guessed (blueprint §3b).
  func modelID(for feature: AIFeature) -> String? {
    defaults.string(forKey: Self.modelKey(feature)).flatMap { $0.isEmpty ? nil : $0 }
  }

  func provider(for feature: AIFeature) -> AIProvider? {
    defaults.string(forKey: Self.providerKey(feature)).flatMap(AIProvider.init(rawValue:))
  }

  func setChoice(_ provider: AIProvider, model: String, for feature: AIFeature) {
    defaults.set(provider.rawValue, forKey: Self.providerKey(feature))
    defaults.set(
      model.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.modelKey(feature))
  }
}

extension AIProvider {
  var title: String {
    switch self {
    case .anthropic: "Anthropic"
    case .openAI: "OpenAI"
    }
  }
}

extension AIFeature {
  var title: String {
    switch self {
    case .diagnosis: "Brew diagnosis"
    case .photoInterpretation: "Photo interpretation"
    case .bagRecognition: "Bag recognition"
    case .insights: "Insights"
    case .paperImport: "Paper import"
    }
  }
}
