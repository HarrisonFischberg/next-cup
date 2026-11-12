import NextCupKit
import SwiftUI

/// One step as the Start brew screen shows it, already scaled to the cup being made.
struct BrewStepRow: Identifiable {
  let index: Int
  let step: RecipeStep
  let startS: Int
  let target: Double?
  var id: RecipeStep.ID { step.id }
  var time: String { RecipeFormat.clock(startS) }
  var name: String { RecipeFormat.title(step.kind) }
}

/// Title, a one-line summary and a quiet Edit.
private struct StepsHeader: View {
  let rows: [BrewStepRow]
  let totalS: Int
  let units: UnitPreferences
  let onEdit: () -> Void

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Brew steps".dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
        Text(summary).font(.footnote).foregroundStyle(DS.ink2)
      }
      Spacer(minLength: DS.Space.sm)
      Button(action: onEdit) {
        Label("Edit", systemImage: "slider.horizontal.3")
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, DS.Space.md).frame(minHeight: 36)
          .overlay(Capsule().strokeBorder(DS.line, lineWidth: 1))
          .contentShape(Capsule())
      }
      .buttonStyle(.plain).foregroundStyle(DS.ink)
      .frame(minHeight: DS.Size.minTap)
      .accessibilityLabel("Edit steps")
      .accessibilityHint("Add or change steps, with optional AI suggestions")
      .accessibilityIdentifier("recipe.steps.change")
    }
  }

  private var summary: String {
    var parts = ["\(rows.count) steps"]
    if let water = rows.compactMap(\.target).max() {
      parts.append(RecipeFormat.weight(water, units))
    }
    parts.append(RecipeFormat.clock(totalS))
    return parts.joined(separator: " · ")
  }
}

/// The Start brew card: one row per step, Apple-list style. Time leads, the pour target sits in a
/// trailing pill, and the first line of the instruction is always there; tap to read it all.
struct BrewStepsCard: View {
  let rows: [BrewStepRow]
  let totalS: Int
  let units: UnitPreferences
  let onEdit: () -> Void
  @State private var open: RecipeStep.ID?

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      StepsHeader(rows: rows, totalS: totalS, units: units, onEdit: onEdit)
      VStack(spacing: 0) {
        ForEach(rows) { row in
          let expanded = open == row.id
          Button {
            withAnimation(.snappy(duration: 0.25)) { open = expanded ? nil : row.id }
          } label: {
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.md) {
              Text(row.time).font(DS.Font.mono(.subheadline, .semibold))
                .foregroundStyle(DS.accent).frame(width: 44, alignment: .leading)
              VStack(alignment: .leading, spacing: 3) {
                Text(row.name).font(.body.weight(.semibold)).foregroundStyle(DS.ink)
                if !row.step.instruction.isEmpty {
                  Text(row.step.instruction).font(.subheadline).foregroundStyle(DS.ink2)
                    .lineLimit(expanded ? nil : 1)
                    .multilineTextAlignment(.leading)
                }
              }
              Spacer(minLength: DS.Space.sm)
              if let target = row.target {
                Text(RecipeFormat.weight(target, units))
                  .font(DS.Font.mono(.footnote, .bold)).foregroundStyle(DS.onSignal)
                  .padding(.horizontal, 10).padding(.vertical, 4)
                  .background(DS.signal, in: Capsule())
              }
            }
            .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.md)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(
            RecipeFormat.spokenStep(
              kind: row.step.kind, startOffsetS: row.startS, targetG: row.target, units: units)
          )
          .accessibilityHint(row.step.instruction)
          .accessibilityIdentifier("recipe.step.\(row.index)")
          if row.index < rows.count - 1 {
            Rectangle().fill(DS.line.opacity(0.35)).frame(height: DS.hairline)
              .padding(.leading, DS.Space.lg + 44 + DS.Space.md)
          }
        }
      }
      .background(DS.paper, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
    }
    .padding(.horizontal, DS.Space.lg)
  }
}
