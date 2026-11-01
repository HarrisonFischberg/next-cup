import Foundation
import NextCupKit
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
    prefs.acceptDisclosure(for: .anthropic)
    prefs.setChoice(.anthropic, model: "m", for: .diagnosis)
    let stored = suite.dictionaryRepresentation().values.map { "\($0)" }
    #expect(!stored.contains { $0.contains("sk-secret-value") })
  }

  @Test func disclosureIsPerProviderAndVersioned() {
    let suite = defaults()
    let prefs = AIPreferences(defaults: suite)
    #expect(!prefs.hasAcceptedDisclosure(for: .anthropic))
    prefs.acceptDisclosure(for: .anthropic)
    #expect(prefs.hasAcceptedDisclosure(for: .anthropic))
    #expect(!prefs.hasAcceptedDisclosure(for: .openAI), "one provider never unlocks another")
    suite.set(
      AIPreferences.disclosureVersion - 1, forKey: AIPreferences.disclosureKey(.anthropic))
    #expect(!prefs.hasAcceptedDisclosure(for: .anthropic))
  }

  @MainActor @Test func disclosureNamesWhatEachFeatureSendsAsThePayloadsDo() {
    let photo = Data([1])
    let withPhoto: [AIFeature: AIRequestPayload] = [
      .bagRecognition: BagRecognition.payload(photo: photo, feature: .bagRecognition),
      .photoInterpretation: BagRecognition.payload(photo: photo, feature: .photoInterpretation),
      .paperImport: PaperImport.payload(photo: photo),
    ]
    for (feature, payload) in withPhoto {
      #expect(payload.imageJPEG != nil)
      #expect(feature.sends.contains("photo"), "\(feature) sends a photo")
      #expect(feature.sends.contains("location and camera data removed"))
    }

    let brews = (0..<10).map { index in
      let brew = Brew(date: Date(timeIntervalSince1970: Double(index) * 86_400))
      brew.notes = "note-\(index)"
      return brew
    }
    let many = AISuggestions.payload(insightsFrom: brews)
    #expect(many.imageJPEG == nil)
    #expect(AIFeature.diagnosis.sends.contains("your notes"))
    #expect(!AIFeature.diagnosis.sends.lowercased().contains("photo"))
    #expect(many.userText.components(separatedBy: "\n- ").count - 1 == 8)
    #expect(AIFeature.insights.sends.contains("8 most recent"))
    #expect(AIFeature.insights.sends.contains("your notes"))
  }

  @Test func modelChoiceIsPerFeatureAndNeverGuessed() {
    let prefs = AIPreferences(defaults: defaults(), appleAvailable: false)
    #expect(prefs.modelID(for: .insights) == nil)
    #expect(prefs.provider(for: .insights) == nil)
    prefs.setChoice(.openAI, model: " my-model ", for: .insights)
    #expect(prefs.modelID(for: .insights) == "my-model")
    #expect(prefs.provider(for: .insights) == .openAI)
    #expect(prefs.modelID(for: .diagnosis) == nil)
  }

  @Test func appleIsTheDefaultWhereAvailableAndNeedsNoKeyOrDisclosure() {
    let prefs = AIPreferences(defaults: defaults(), appleAvailable: true)
    #expect(prefs.provider(for: .diagnosis) == .apple)
    #expect(prefs.modelID(for: .diagnosis) == AppleIntelligence.modelID)
    #expect(prefs.hasAcceptedDisclosure(for: .apple))
    #expect(store().hasKey(for: .apple))
    prefs.setChoice(.openAI, model: "m", for: .diagnosis)
    #expect(prefs.provider(for: .diagnosis) == .openAI, "a choice beats the default")
  }

  @Test func effortIsStoredOnceForEveryFeature() {
    let prefs = AIPreferences(defaults: defaults())
    #expect(prefs.effort == nil)
    prefs.effort = "low"
    #expect(prefs.effort == "low")
    prefs.effort = ""
    #expect(prefs.effort == nil)
  }
}
