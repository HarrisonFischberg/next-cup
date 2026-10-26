import SwiftUI

/// Settings → AI: bring-your-own keys, the one-time disclosure and a provider
/// and model for each feature. Nothing here makes a network call.
struct AISettingsView: View {
  private let keychain = KeychainStore()
  @State private var drafts: [AIProvider: String] = [:]
  @State private var saved: Set<AIProvider> = []
  @State private var pending: AIProvider?
  @State private var errorMessage: String?
  @State private var defaultProvider = AIProvider.anthropic
  @State private var defaultModel = ""
  /// Rebuilds the per-feature rows after "Use for every feature" rewrites them.
  @State private var perFeatureID = UUID()

  /// AI setup is two steps; say how far along it is.
  private var setupLine: String {
    let key = !saved.isEmpty
    let model = AIFeature.allCases.contains { AIPreferences().modelID(for: $0) != nil }
    let done = (key ? 1 : 0) + (model ? 1 : 0)
    return done == 2
      ? "Set up: key and model are ready."
      : "\(done) of 2 set up: key \(key ? "✓" : "○"), model \(model ? "✓" : "○")"
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
        Text(setupLine).font(.subheadline.weight(.semibold)).foregroundStyle(DS.ink)
          .listRowBackground(DS.paper)
          .accessibilityIdentifier("ai.setup")
      }
      ForEach(AIProvider.allCases, id: \.self) { provider in keySection(provider) }
      Section {
        Picker("Provider", selection: $defaultProvider) {
          ForEach(AIProvider.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .listRowBackground(DS.paper)
        TextField("Model ID", text: $defaultModel)
          .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.done)
          .frame(minHeight: DS.Size.control).listRowBackground(DS.paper)
          .accessibilityIdentifier("ai.model.default")
        Button("Use for every feature") {
          let preferences = AIPreferences()
          for feature in AIFeature.allCases {
            preferences.setChoice(defaultProvider, model: defaultModel, for: feature)
          }
          perFeatureID = UUID()
        }
        .frame(minHeight: DS.Size.control).listRowBackground(DS.paper)
        .disabled(defaultModel.trimmingCharacters(in: .whitespaces).isEmpty)
        .accessibilityIdentifier("ai.model.applyAll")
      } header: {
        Text("Model")
      } footer: {
        Text("Type the model ID your provider documents. Nothing is chosen for you.")
      }
      Section {
        DisclosureGroup("A different model for each feature") {
          ForEach(AIFeature.allCases, id: \.self) { feature in FeatureModelRow(feature: feature) }
        }
        .id(perFeatureID)
        .listRowBackground(DS.paper)
      } header: {
        Text("Advanced")
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(DS.bg)
    .navigationTitle("AI")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { saved = Set(AIProvider.allCases.filter(keychain.hasKey)) }
    .sheet(item: $pending) { provider in
      AIDisclosureView(provider: provider) {
        AIPreferences().acceptDisclosure(for: provider)
        pending = nil
        store(provider)
      } cancel: {
        pending = nil
      }
    }
    .accessibilityIdentifier("settings.ai.root")
  }

  private func keySection(_ provider: AIProvider) -> some View {
    Section {
      if saved.contains(provider) {
        LabeledContent("Key", value: "Saved on this iPhone")
          .listRowBackground(DS.paper)
        Button("Remove key", role: .destructive) { remove(provider) }
          .frame(minHeight: DS.Size.control).listRowBackground(DS.paper)
          .accessibilityIdentifier("ai.remove.\(provider.rawValue)")
      } else {
        SecureField(
          "API key",
          text: Binding(get: { drafts[provider] ?? "" }, set: { drafts[provider] = $0 })
        )
        .textContentType(nil).textInputAutocapitalization(.never).autocorrectionDisabled()
        .submitLabel(.done).frame(minHeight: DS.Size.control).listRowBackground(DS.paper)
        .accessibilityIdentifier("ai.key.\(provider.rawValue)")
        Button("Save key") { requestSave(provider) }
          .frame(minHeight: DS.Size.control).listRowBackground(DS.paper)
          .disabled((drafts[provider] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
          .accessibilityIdentifier("ai.save.\(provider.rawValue)")
      }
    } header: {
      Text(provider.title)
    } footer: {
      Text("Kept in the Keychain on this device only. Not backed up, not exported.")
    }
  }

  private func requestSave(_ provider: AIProvider) {
    if AIPreferences().hasAcceptedDisclosure(for: provider) {
      store(provider)
    } else {
      pending = provider
    }
  }

  private func store(_ provider: AIProvider) {
    do {
      try keychain.setKey(drafts[provider] ?? "", for: provider)
      drafts[provider] = nil
      saved.insert(provider)
      errorMessage = nil
    } catch {
      errorMessage = "The key was not saved. \(error.localizedDescription)"
    }
  }

  private func remove(_ provider: AIProvider) {
    do {
      try keychain.removeKey(for: provider)
      saved.remove(provider)
    } catch {
      errorMessage = "The key was not removed. \(error.localizedDescription)"
    }
  }
}

extension AIProvider: Identifiable {
  var id: String { rawValue }
}

private struct FeatureModelRow: View {
  let feature: AIFeature
  @AppStorage private var provider: String
  @AppStorage private var model: String

  init(feature: AIFeature) {
    self.feature = feature
    _provider = AppStorage(
      wrappedValue: AIProvider.anthropic.rawValue, AIPreferences.providerKey(feature))
    _model = AppStorage(wrappedValue: "", AIPreferences.modelKey(feature))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text(feature.title).font(DS.Font.headline).foregroundStyle(DS.ink)
      Picker("Provider", selection: $provider) {
        ForEach(AIProvider.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
      }
      .pickerStyle(.segmented)
      TextField("Model ID", text: $model)
        .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.done)
        .frame(minHeight: DS.Size.control)
        .accessibilityIdentifier("ai.model.\(feature.rawValue)")
    }
    .padding(.vertical, DS.Space.xs)
    .listRowBackground(DS.paper)
    .accessibilityElement(children: .contain)
    // The picker shows Anthropic by default; write it so the choice is real.
    .onAppear { if AIPreferences().provider(for: feature) == nil { provider = provider } }
  }
}
