import NextCupKit
import SwiftUI

/// The dial-in card on the brew form: one change to try, why, and three answers.
/// Accept applies it to this brew, Edit changes the value first, Dismiss sets it
/// aside. Every answer has an Undo, so nothing needs a confirm dialog.
struct SuggestionCard: View {
  let suggestion: Suggestion
  let units: UnitPreferences
  var error: String?
  let onAccept: () -> Void
  /// Called with the typed text (in the user's unit); the model validates it.
  let onEdit: (String) -> Void
  let onDismiss: () -> Void
  let onUndo: () -> Void

  @Environment(\.dynamicTypeSize) private var dts
  @State private var editing = false
  @State private var typed = ""

  var body: some View {
    KraftNote {
      VStack(alignment: .leading, spacing: DS.Space.sm) {
        Text(label).font(DS.Font.label).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
        Text(SuggestionFormat.headline(suggestion, units))
          .font(DS.Font.mono(.title3, .bold)).foregroundStyle(DS.ink)
          .accessibilityLabel(SuggestionFormat.spoken(suggestion, units))
          .accessibilityIdentifier("suggestion.headline")
        Text(suggestion.rationale).font(.footnote).foregroundStyle(DS.ink)
        if let source = suggestion.sourceBrew {
          Text("From your brew on \(source.date.formatted(date: .abbreviated, time: .omitted)).")
            .font(.footnote).foregroundStyle(DS.ink)
        }
        if let error {
          Text(error).font(.footnote.weight(.semibold)).foregroundStyle(DS.error)
        }
        actions
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("suggestion.card")
    .alert("Edit the change", isPresented: $editing) {
      TextField(unitLabel, text: $typed)
        .keyboardType(keyboard)
      Button("Cancel", role: .cancel) {}
      Button("Apply") { onEdit(typed) }
    } message: {
      Text("\(SuggestionFormat.title(suggestion.field)) for this brew\(unitHint).")
    }
  }

  private var label: String {
    switch suggestion.state {
    case .proposed: "TRY THIS NEXT"
    case .accepted: "APPLIED TO THIS BREW"
    case .edited: "APPLIED, WITH YOUR EDIT"
    case .dismissed: "DISMISSED"
    }
  }

  @ViewBuilder private var actions: some View {
    switch suggestion.state {
    case .proposed:
      let layout =
        dts.isAccessibilitySize
        ? AnyLayout(VStackLayout(spacing: DS.Space.sm))
        : AnyLayout(HStackLayout(spacing: DS.Space.sm))
      layout {
        SteelButton(title: "Accept", action: onAccept)
          .accessibilityIdentifier("suggestion.accept")
        SteelButton(title: "Edit", kind: .secondary) {
          typed = SuggestionFormat.editable(suggestion.toValue, for: suggestion.field, units)
          editing = true
        }
        .accessibilityIdentifier("suggestion.edit")
        SteelButton(title: "Dismiss", kind: .secondary, action: onDismiss)
          .accessibilityIdentifier("suggestion.dismiss")
      }
    case .accepted, .edited, .dismissed:
      SteelButton(title: "Undo", kind: .secondary, action: onUndo)
        .accessibilityIdentifier("suggestion.undo")
    }
  }

  private var keyboard: UIKeyboardType {
    switch suggestion.field {
    case .grind: .default
    case .time: .numberPad
    default: .decimalPad
    }
  }

  private var unitLabel: String {
    switch suggestion.field {
    case .water, .yield: units.weightSymbol
    case .temperature: units.temperatureSymbol
    case .time: "Seconds"
    default: "Grind setting"
    }
  }

  private var unitHint: String {
    switch suggestion.field {
    case .water, .yield: ", in \(units.weightSymbol)"
    case .temperature: ", in \(units.temperatureSymbol)"
    case .time: ", in seconds"
    default: ""
    }
  }
}

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
