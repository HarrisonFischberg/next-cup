import NextCupKit
import SwiftData
import SwiftUI

/// The sheet behind "Ask AI about this brew" and Explore's insights. It first shows
/// exactly what would be sent, then waits for a tap. Setup problems say where to fix
/// them; offline waits and failures keep Cancel and Try again in reach.
struct AIAskView: View {
  let close: () -> Void
  @State private var model: AIAskModel
  @State private var disclosureProvider: AIProvider?
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  init(model: AIAskModel, close: @escaping () -> Void) {
    self.close = close
    _model = State(initialValue: model)
  }

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
          preview
          status
        }
        .padding(DS.Space.lg)
      }
      .background(DS.bg)
      .navigationTitle(model.feature.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { close() }.accessibilityIdentifier("ai.ask.close")
        }
      }
      .onChange(of: model.request?.status) { _, _ in model.statusChanged() }
      .sheet(item: $disclosureProvider) { provider in
        AIDisclosureView(provider: provider) {
          model.acceptDisclosure(for: provider)
          disclosureProvider = nil
          model.send()
        } cancel: {
          disclosureProvider = nil
        }
      }
      .onDisappear { model.leave() }
    }
    .accessibilityIdentifier("ai.ask")
  }

  // MARK: Preview

  private var preview: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("WHAT WILL BE SENT").font(DS.Font.label).foregroundStyle(DS.ink2)
        .accessibilityAddTraits(.isHeader)
      PaperBox {
        Text(model.payload.userText).font(DS.Font.mono(.footnote)).foregroundStyle(DS.ink)
          .padding(DS.Space.md).frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
          .accessibilityIdentifier("ai.ask.preview")
      }
      Text(destination).font(.footnote).foregroundStyle(DS.ink2)
        .accessibilityIdentifier("ai.ask.destination")
    }
  }

  private var destination: String {
    switch model.readiness {
    case .ready(let provider, let modelID), .needsDisclosure(let provider, let modelID):
      "Goes to \(provider.title) (\(modelID)) with your own key. Nothing is sent until you tap Send."
    case .needsKey(let provider):
      "Would go to \(provider.title). Nothing is sent without your key."
    case .needsChoice:
      "Nothing is sent until you choose a provider and model."
    }
  }

  // MARK: Status

  @ViewBuilder private var status: some View {
    if let suggestion = model.suggestion {
      result(suggestion)
    } else if let message = model.errorMessage {
      StateBanner(kind: .error, message: message, actionTitle: "Try again") { model.retry() }
        .accessibilityIdentifier("ai.ask.error")
    } else if model.isWorking {
      working
    } else {
      sendControls
    }
  }

  @ViewBuilder private var sendControls: some View {
    switch model.readiness {
    case .needsChoice:
      StateBanner(
        kind: .info,
        message:
          "Choose a provider and a model for \(model.feature.title) in Settings → AI, then come back."
      )
      .accessibilityIdentifier("ai.ask.setup")
    case .needsKey(let provider):
      StateBanner(
        kind: .info, message: "Add your \(provider.title) key in Settings → AI, then come back."
      )
      .accessibilityIdentifier("ai.ask.setup")
    case .needsDisclosure(let provider, _):
      SteelButton(title: "Review and send") { disclosureProvider = provider }
        .accessibilityIdentifier("ai.ask.send")
    case .ready(let provider, _):
      SteelButton(title: "Send to \(provider.title)") { model.send() }
        .accessibilityIdentifier("ai.ask.send")
    }
  }

  private var working: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      SkeletonRow()
      if model.isWaitingForConnection {
        StateBanner(
          kind: .offline,
          message: "Waiting for a connection. It sends when you are back online."
        )
        .accessibilityIdentifier("ai.ask.offline")
      } else {
        Text("Asking").font(.headline).foregroundStyle(DS.ink)
          .accessibilityIdentifier("ai.ask.working")
      }
      SteelButton(title: "Cancel", kind: .secondary) { model.cancel() }
        .accessibilityIdentifier("ai.ask.cancel")
    }
  }

  private func result(_ suggestion: Suggestion) -> some View {
    let dismissed = suggestion.state == .dismissed
    return VStack(alignment: .leading, spacing: DS.Space.md) {
      KraftNote {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
          Text(dismissed ? "DISMISSED" : "TRY THIS NEXT").font(DS.Font.label)
            .foregroundStyle(DS.ink).accessibilityAddTraits(.isHeader)
          Text(SuggestionFormat.headline(suggestion, units))
            .font(DS.Font.mono(.title3, .bold)).foregroundStyle(DS.ink)
            .accessibilityLabel(SuggestionFormat.spoken(suggestion, units))
            .accessibilityIdentifier("ai.ask.headline")
          Text(suggestion.rationale).font(.footnote).foregroundStyle(DS.ink)
          if let modelID = suggestion.modelID {
            Text("Suggested by \(modelID).").font(.footnote).foregroundStyle(DS.ink)
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("ai.ask.card")
      Text(
        dismissed
          ? "It will not show on your next brew."
          : "Saved with this brew. It appears on your next brew of this coffee, where you can accept, edit or dismiss it."
      )
      .font(.footnote).foregroundStyle(DS.ink2)
      SteelButton(title: dismissed ? "Undo" : "Dismiss", kind: .secondary) {
        model.setDismissed(!dismissed)
      }
      .accessibilityIdentifier(dismissed ? "ai.ask.undo" : "ai.ask.dismiss")
    }
  }
}
