import SwiftUI

/// Shown before the first AI action for a provider, and again when the text or the
/// provider changes. Lists exactly what each feature sends to that provider.
struct AIDisclosureView: View {
  let provider: AIProvider
  let agree: () -> Void
  let cancel: () -> Void

  var body: some View {
    NavigationStack {
      List {
        Section {
          Text(
            "When you tap an AI action, Next Cup sends the data below to \(provider.title), using your own key."
          )
          Text(
            "Nothing is sent until you tap, and never without a key. \(provider.title) handles the request under its own terms. Next Cup has no server and sees none of it."
          )
          Text(
            "Next Cup deletes its own copy of the photo and the request as soon as the request ends, whether it worked, failed or was cancelled."
          )
          Text("\(provider.title) may charge your own account for each request.")
        }
        .font(.body).foregroundStyle(DS.ink).listRowBackground(DS.paper)
        Section("What each action sends") {
          ForEach(AIFeature.allCases, id: \.self) { feature in
            VStack(alignment: .leading, spacing: DS.Space.xs) {
              Text(feature.title).font(DS.Font.headline).foregroundStyle(DS.ink)
              Text(feature.sends).font(.body).foregroundStyle(DS.ink2)
            }
            .accessibilityElement(children: .combine)
          }
          .listRowBackground(DS.paper)
        }
        Section {
          Text("You can remove the key at any time in Settings → AI.")
            .font(.body).foregroundStyle(DS.ink)
        }
        .listRowBackground(DS.paper)
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(DS.bg)
      .navigationTitle("Before you use \(provider.title)")
      .navigationBarTitleDisplayMode(.inline)
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: DS.Space.sm) {
          SteelButton(title: "I understand", action: agree)
            .accessibilityIdentifier("ai.disclosure.agree")
          SteelButton(title: "Not now", kind: .secondary, action: cancel)
            .accessibilityIdentifier("ai.disclosure.cancel")
        }
        .padding(DS.Space.lg).background(DS.bg)
      }
    }
    .accessibilityIdentifier("ai.disclosure")
  }
}
