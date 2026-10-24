import Foundation
import Testing

@testable import NextCup

@Suite("AIConfig")
struct AIConfigTests {
  private func store() -> KeychainStore {
    KeychainStore(service: "test.nextcup.\(UUID().uuidString)")
  }

  private func defaults() -> UserDefaults {
    UserDefaults(suiteName: "test.nextcup.\(UUID().uuidString)")!
  }

  @Test func keychainRoundTrip() throws {
    let keychain = store()
    defer { for provider in AIProvider.allCases { try? keychain.removeKey(for: provider) } }
    #expect(try keychain.key(for: .anthropic) == nil)
    try keychain.setKey("  sk-test-1 \n", for: .anthropic)
    #expect(try keychain.key(for: .anthropic) == "sk-test-1")
    try keychain.setKey("sk-test-2", for: .anthropic)
    #expect(try keychain.key(for: .anthropic) == "sk-test-2")
    #expect(try keychain.key(for: .openAI) == nil)
    try keychain.removeKey(for: .anthropic)
    #expect(!keychain.hasKey(for: .anthropic))
  }

  @Test func emptyKeyRemoves() throws {
    let keychain = store()
    try keychain.setKey("sk-test", for: .openAI)
    try keychain.setKey("   ", for: .openAI)
    #expect(!keychain.hasKey(for: .openAI))
  }

  @Test func keyNeverReachesPreferences() throws {
    let keychain = store()
    let suite = defaults()
    defer { try? keychain.removeKey(for: .anthropic) }
    let prefs = AIPreferences(defaults: suite)
    try keychain.setKey("sk-secret-value", for: .anthropic)
    prefs.acceptDisclosure()
    prefs.setChoice(.anthropic, model: "m", for: .diagnosis)
    let stored = suite.dictionaryRepresentation().values.map { "\($0)" }
    #expect(!stored.contains { $0.contains("sk-secret-value") })
  }

  @Test func disclosureIsOnceAndVersioned() {
    let suite = defaults()
    let prefs = AIPreferences(defaults: suite)
    #expect(!prefs.hasAcceptedDisclosure)
    prefs.acceptDisclosure()
    #expect(prefs.hasAcceptedDisclosure)
    suite.set(AIPreferences.disclosureVersion - 1, forKey: AIPreferences.disclosureKey)
    #expect(!prefs.hasAcceptedDisclosure)
  }

  @Test func modelChoiceIsPerFeatureAndNeverGuessed() {
    let prefs = AIPreferences(defaults: defaults())
    #expect(prefs.modelID(for: .insights) == nil)
    #expect(prefs.provider(for: .insights) == nil)
    prefs.setChoice(.openAI, model: " my-model ", for: .insights)
    #expect(prefs.modelID(for: .insights) == "my-model")
    #expect(prefs.provider(for: .insights) == .openAI)
    #expect(prefs.modelID(for: .diagnosis) == nil)
  }
}
