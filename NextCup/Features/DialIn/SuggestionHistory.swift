import NextCupKit
import SwiftUI

/// What the rules said about a saved brew, read-only, for the journal and the
/// edit form (X4).
struct SuggestionHistory: View {
  let brew: Brew
  let units: UnitPreferences

  var body: some View {
    let made = (brew.suggestionsMade ?? []).sorted { $0.createdAt > $1.createdAt }
    if !made.isEmpty {
      VStack(alignment: .leading, spacing: DS.Space.sm) {
        Text("DIAL-IN FROM THIS BREW").font(DS.Font.label).foregroundStyle(DS.ink2)
          .accessibilityAddTraits(.isHeader)
        PaperBox {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(made.enumerated()), id: \.element.id) { index, suggestion in
              if index > 0 { Hairline() }
              VStack(alignment: .leading, spacing: 2) {
                Text(SuggestionFormat.headline(suggestion, units))
                  .font(DS.Font.mono(.callout, .bold)).foregroundStyle(DS.ink)
                Text(suggestion.rationale).font(.footnote).foregroundStyle(DS.ink2)
                Text(SuggestionFormat.title(suggestion.state).uppercased())
                  .font(DS.Font.label).foregroundStyle(DS.ink2)
              }
              .padding(DS.Space.md).frame(maxWidth: .infinity, alignment: .leading)
              .accessibilityElement(children: .combine)
            }
          }
        }
        .accessibilityIdentifier("brewform.dialin.history")
      }
    }
  }
}
