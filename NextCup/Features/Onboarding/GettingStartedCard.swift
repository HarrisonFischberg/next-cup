import SwiftData
import SwiftUI

/// The Journal's first-run card: what is already set up counts as done, so the
/// list reads "3 of 4 set up" rather than a blank page. It goes away for good
/// once the first brew is logged, or when dismissed.
struct GettingStartedCard: View {
  static let dismissedKey = "gettingStarted.dismissed"

  let logBrew: () -> Void
  let importPage: () -> Void

  @Query private var methods: [BrewMethod]
  @Query private var beans: [Bean]
  @AppStorage(AppTab.storageKey) private var storedTab = AppTab.journal.rawValue
  @AppStorage(dismissedKey) private var dismissed = false

  private var steps: [(title: String, done: Bool)] {
    [
      ("Brew methods ready", !methods.isEmpty),
      ("Units set", true),
      ("Add your first bag", !beans.isEmpty),
      ("Log your first brew", false),
    ]
  }

  var body: some View {
    let done = steps.filter(\.done).count
    VStack(alignment: .leading, spacing: DS.Space.lg) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
          Text("Getting started".dsTitle).font(DS.Font.display).foregroundStyle(DS.ink)
            .dynamicTypeSize(...DS.displayCap)
            .accessibilityAddTraits(.isHeader)
          Text("\(done) of \(steps.count) set up").font(.subheadline).foregroundStyle(DS.ink2)
            .accessibilityIdentifier("gettingStarted.count")
        }
        Spacer(minLength: DS.Space.sm)
        Button {
          dismissed = true
        } label: {
          Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(DS.ink2)
            .frame(width: DS.Size.minTap, height: DS.Size.minTap)
        }
        .accessibilityLabel("Hide getting started")
      }
      VStack(alignment: .leading, spacing: DS.Space.sm) {
        ForEach(steps, id: \.title) { step in
          HStack(spacing: DS.Space.sm) {
            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(step.done ? DS.sage : DS.line).accessibilityHidden(true)
            if step.title == "Add your first bag" && !step.done {
              Button(step.title) { storedTab = AppTab.beans.rawValue }
                .foregroundStyle(DS.ink).underline()
            } else {
              Text(step.title).foregroundStyle(step.done ? DS.ink2 : DS.ink)
            }
          }
          .font(.callout)
          .frame(minHeight: DS.Size.minTap, alignment: .leading)
          .accessibilityElement(children: .combine)
          .accessibilityValue(step.done ? "Done" : "Not done")
        }
      }
      SteelButton(title: "Log a brew", action: logBrew)
      Button("Import a journal page", action: importPage)
        .font(.body.weight(.semibold)).foregroundStyle(DS.ink)
        .frame(maxWidth: .infinity, minHeight: DS.Size.minTap)
        .accessibilityIdentifier("journal.import")
    }
    .padding(DS.Space.lg)
    .background(
      DS.paper,
      in: RoundedRectangle(cornerRadius: DS.isBloom ? 32 : DS.controlRadius, style: .continuous)
    )
    .padding(DS.Space.lg)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("gettingStarted")
  }
}
