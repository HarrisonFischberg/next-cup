import NextCupKit
import SwiftUI

/// Settings → AI: one provider, model and effort for every feature, then the keys. A key is
/// checked by listing its models before it is saved, and that list is what the model picker
/// offers. Apple's on-device model needs no key.
struct AISettingsView: View {
  private let keychain = KeychainStore()
  private let preferences = AIPreferences()
  @State private var drafts: [AIProvider: String] = [:]
  @State private var saved: Set<AIProvider> = []
  @State private var models: [AIProvider: [String]] = [:]
  @State private var checking: AIProvider?
  @State private var pending: AIProvider?
  @State private var errorMessage: String?
  @State private var provider: AIProvider
  @State private var model: String
  @State private var effort: String

  init() {
    let preferences = AIPreferences()
    _provider = State(initialValue: preferences.provider(for: .diagnosis) ?? .anthropic)
    _model = State(initialValue: preferences.modelID(for: .diagnosis) ?? "")
    _effort = State(initialValue: preferences.effort ?? "")
  }

  private var choices: [AIProvider] {
    (preferences.appleAvailable ? [.apple] : []) + AIProvider.keyed.filter(saved.contains)
  }

  var body: some View {
    List {
      if let errorMessage {
        StateBanner(kind: .error, message: errorMessage, actionTitle: "Dismiss") {
          self.errorMessage = nil
        }
        .accessibilityIdentifier("ai.error")
        .listRowInsets(EdgeInsets())
        .listRowBackground(DS.bg)
      }
      Section {
        if choices.isEmpty {
          Text("Add a key below to choose a model.").font(.footnote).foregroundStyle(DS.ink2)
            .listRowBackground(DS.paper)
        } else {
          Picker("Provider", selection: $provider) {
            ForEach(choices) { Text($0.title).tag($0) }
          }
          .listRowBackground(DS.paper)
          .accessibilityIdentifier("ai.provider")
          modelRow.listRowBackground(DS.paper)
          if provider != .apple {
            Picker("Effort", selection: $effort) {
              Text("Default").tag("")
              Text("Low").tag("low")
              Text("Medium").tag("medium")
              Text("High").tag("high")
            }
            .listRowBackground(DS.paper)
            .accessibilityIdentifier("ai.effort")
          }
        }
      } header: {
        Text("Model")
      } footer: {
        Text("Used for every AI feature.")
      }
      ForEach(AIProvider.keyed) { keySection($0) }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(DS.bg)
    .navigationTitle("AI")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      saved = Set(AIProvider.keyed.filter(keychain.hasKey))
      for provider in saved { await loadModels(provider) }
    }
    .onChange(of: provider) {
      model =
        provider == .apple
        ? AppleIntelligence.modelID : (models[provider]?.contains(model) == true ? model : "")
      apply()
    }
    .onChange(of: model) { apply() }
    .onChange(of: effort) { preferences.effort = effort }
    .sheet(item: $pending) { provider in
      AIDisclosureView(provider: provider) {
        preferences.acceptDisclosure(for: provider)
        pending = nil
        store(provider)
      } cancel: {
        pending = nil
      }
    }
    .accessibilityIdentifier("settings.ai.root")
  }

  @ViewBuilder private var modelRow: some View {
    if provider == .apple {
      LabeledContent("Model", value: "On this iPhone")
    } else if let list = models[provider] {
      Picker("Model", selection: $model) {
        if !list.contains(model) { Text("Choose…").tag(model) }
        ForEach(list, id: \.self) { Text($0).tag($0) }
      }
      .accessibilityIdentifier("ai.model")
    } else {
      LabeledContent("Model") { ProgressView() }
    }
  }

  private func keySection(_ provider: AIProvider) -> some View {
    Section {
      if saved.contains(provider) {
        HStack {
          Text(models[provider].map { "Key works · \($0.count) models" } ?? "Key saved")
            .foregroundStyle(DS.ink)
          Spacer()
          Button("Remove", role: .destructive) { remove(provider) }
            .accessibilityIdentifier("ai.remove.\(provider.rawValue)")
        }
        .frame(minHeight: DS.Size.control)
        .listRowBackground(DS.paper)
      } else {
        HStack {
          SecureField(
            "\(provider.title) API key",
            text: Binding(get: { drafts[provider] ?? "" }, set: { drafts[provider] = $0 })
          )
          .textContentType(nil).textInputAutocapitalization(.never).autocorrectionDisabled()
          .submitLabel(.done)
          .accessibilityIdentifier("ai.key.\(provider.rawValue)")
          if checking == provider {
            ProgressView()
          } else {
            Button("Save") { requestSave(provider) }
              .disabled((drafts[provider] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
              .accessibilityIdentifier("ai.save.\(provider.rawValue)")
          }
        }
        .frame(minHeight: DS.Size.control)
        .listRowBackground(DS.paper)
      }
    } header: {
      Text(provider.title)
    } footer: {
      if provider == AIProvider.keyed.last {
        Text("Keys stay in this iPhone's Keychain. Not backed up, not exported.")
      }
    }
  }

  private func apply() {
    guard !model.isEmpty else { return }
    for feature in AIFeature.allCases {
      preferences.setChoice(provider, model: model, for: feature)
    }
  }

  /// An AI client for listing models only: it sends nothing but the key.
  private func client(_ key: String?) -> AIClient {
    AIClient(transport: URLSessionTransport(), key: { _ in key }, disclosureAccepted: { _ in true })
  }

  private func loadModels(_ provider: AIProvider) async {
    guard let kind = provider.kind else { return }
    let key = (try? keychain.key(for: provider)) ?? nil
    models[provider] = try? await client(key).models(kind)
  }

  private func requestSave(_ provider: AIProvider) {
    if preferences.hasAcceptedDisclosure(for: provider) {
      store(provider)
    } else {
      pending = provider
    }
  }

  /// Checks the key by listing its models; only a key the provider accepts is saved.
  private func store(_ provider: AIProvider) {
    guard let kind = provider.kind else { return }
    let key = (drafts[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    checking = provider
    Task {
      defer { checking = nil }
      do {
        let list = try await client(key).models(kind)
        try keychain.setKey(key, for: provider)
        drafts[provider] = nil
        saved.insert(provider)
        models[provider] = list
        errorMessage = nil
        if self.provider == .apple || !choices.contains(self.provider) { self.provider = provider }
      } catch AIError.keyRejected {
        errorMessage = "\(provider.title) did not accept this key. Check it and try again."
      } catch let error as AIError {
        errorMessage = "The key was not checked. \(error.errorDescription ?? "")"
      } catch {
        errorMessage = "The key was not saved. \(error.localizedDescription)"
      }
    }
  }

  private func remove(_ provider: AIProvider) {
    do {
      try keychain.removeKey(for: provider)
      saved.remove(provider)
      models[provider] = nil
      if self.provider == provider { self.provider = choices.first ?? .anthropic }
    } catch {
      errorMessage = "The key was not removed. \(error.localizedDescription)"
    }
  }
}

extension AIProvider: Identifiable {
  var id: String { rawValue }
}
