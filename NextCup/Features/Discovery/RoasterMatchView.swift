import SwiftUI

/// T031: after a bag is read, offers real businesses that match the roaster name.
/// Choosing one only hands it back to the bean editor; the bean is saved there.
struct RoasterMatchView: View {
  let onPick: (RoasterPlace) -> Void
  let onSkip: () -> Void

  @State private var model: RoasterMatchModel

  init(
    name: String, searcher: RoasterSearching = liveRoasterSearcher(),
    onPick: @escaping (RoasterPlace) -> Void, onSkip: @escaping () -> Void
  ) {
    _model = State(initialValue: RoasterMatchModel(name: name, searcher: searcher))
    self.onPick = onPick
    self.onSkip = onSkip
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          switch model.phase {
          case .searching:
            ForEach(0..<3, id: \.self) { _ in
              SkeletonRow().listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
            }
          case .failed(let message):
            StateBanner(
              kind: model.isOffline ? .offline : .error, message: message, actionTitle: "Retry"
            ) {
              Task { await model.search() }
            }
            .accessibilityIdentifier("roastermatch.failed")
            .listRowInsets(EdgeInsets()).listRowBackground(DS.bg)
          case .results:
            if model.places.isEmpty {
              EmptyState(
                title: "No match found",
                message: "Skip to keep \(model.name) as typed, or try again later."
              )
              .accessibilityIdentifier("roastermatch.empty")
              .listRowInsets(EdgeInsets()).listRowBackground(DS.bg)
            }
            ForEach(model.places) { place in
              Button {
                onPick(place)
              } label: {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                  Text(place.name.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
                  if let city = place.city {
                    Text(city).font(.footnote).foregroundStyle(DS.ink2)
                  }
                  if let site = place.website?.host() {
                    Text(site).font(.footnote).foregroundStyle(DS.ink2)
                  }
                }
                .padding(DS.Space.md)
                .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
              }
              .buttonStyle(PressableStyle())
              .accessibilityElement(children: .combine)
              .accessibilityHint("Uses this business as the roaster")
              .accessibilityIdentifier("roastermatch.pick.\(place.name)")
              .listRowInsets(EdgeInsets())
              .listRowBackground(DS.paper)
              .listRowSeparatorTint(DS.line)
            }
          }
        } footer: {
          Text("Searched with Apple Maps. Nothing is saved until you save the bean.")
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(DS.bg)
      .navigationTitle("Match roaster")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Skip", action: onSkip).accessibilityIdentifier("roastermatch.skip")
        }
      }
      .task { await model.search() }
      .accessibilityIdentifier("roastermatch.screen")
    }
  }
}
