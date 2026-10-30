import NextCupKit
import SwiftUI

/// What "Improve with AI" suggests: why, each change, and the whole set of steps it would
/// use. "Use these steps" puts them in the editor (still unsaved); "Keep mine" leaves it.
struct RecipeReviewSheet: View {
  let review: RecipeReviewAI.Review
  let units: UnitPreferences
  let use: () -> Void
  let keep: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
          if !review.summary.isEmpty {
            Text(review.summary).font(.body).foregroundStyle(DS.ink)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("recipe.review.summary")
          }
          changes
          numbers
          steps
          Text("Suggested by \(review.source). Check it before you brew.")
            .font(.footnote).foregroundStyle(DS.ink2)
        }
        .padding(DS.Space.lg)
      }
      .background(DS.bg)
      .navigationTitle("Suggested steps")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Keep mine", action: keep).accessibilityIdentifier("recipe.review.keep")
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        SteelButton(title: "Use these steps", action: use)
          .accessibilityIdentifier("recipe.review.use")
          .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.md)
          .background(DS.bg, ignoresSafeAreaEdges: .bottom)
          .overlay(alignment: .top) { Hairline().opacity(0.5) }
      }
    }
    .accessibilityIdentifier("recipe.review")
  }

  @ViewBuilder private var changes: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      SectionRule("What changed")
      if review.changes.isEmpty {
        Text("Nothing: your steps already work.").font(.body).foregroundStyle(DS.ink2)
      }
      ForEach(Array(review.changes.enumerated()), id: \.offset) { _, change in
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
          Image(systemName: "sparkles").foregroundStyle(DS.accent).accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 2) {
            Text(change.what).font(.body.weight(.semibold)).foregroundStyle(DS.ink)
            if !change.why.isEmpty {
              Text(change.why).font(.subheadline).foregroundStyle(DS.ink2)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
        .accessibilityElement(children: .combine)
      }
    }
  }

  @ViewBuilder private var numbers: some View {
    let figures = [
      review.tempC.map { RecipeFormat.temperature($0, units) },
      review.totalTimeS.map { "\(RecipeFormat.clock($0)) total" },
    ]
    .compactMap { $0 }
    if !figures.isEmpty {
      Text(figures.joined(separator: "  ·  "))
        .font(DS.Font.mono(.subheadline, .semibold)).foregroundStyle(DS.ink)
    }
  }

  private var steps: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      SectionRule("Steps")
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(review.steps.enumerated()), id: \.element.id) { index, step in
          TimelineRow(
            time: RecipeFormat.clock(step.startOffsetS), name: RecipeFormat.title(step.kind),
            detail: step.instruction.isEmpty ? nil : step.instruction,
            trailing: step.targetCumulativeWaterG.map { RecipeFormat.weight($0, units) },
            isLast: index == review.steps.count - 1)
        }
      }
    }
  }
}
