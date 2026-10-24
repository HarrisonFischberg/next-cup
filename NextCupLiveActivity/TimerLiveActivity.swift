import ActivityKit
import SwiftUI
import WidgetKit

/// The brew timer on the Lock Screen and in the Dynamic Island. The clock is a
/// system `Text(timerInterval:)`, so it keeps counting with no updates from the
/// app; the app only pushes step and pause changes.
struct TimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TimerActivityAttributes.self) { context in
      LockScreenTimer(attributes: context.attributes, state: context.state)
        .activityBackgroundTint(DS.steel)
        .widgetURL(context.attributes.linkURL)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.attributes.recipeName.uppercased()).font(DS.Font.label)
            .foregroundStyle(DS.onSteel).lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
          BrewClock(state: context.state).font(DS.Font.mono(.title3, .bold))
            .foregroundStyle(DS.signalOnSteel).frame(maxWidth: 90, alignment: .trailing)
        }
        DynamicIslandExpandedRegion(.bottom) {
          StepLine(attributes: context.attributes, state: context.state)
        }
      } compactLeading: {
        Image(systemName: context.state.pausedAt == nil ? "cup.and.heat.waves.fill" : "pause.fill")
          .foregroundStyle(DS.signalOnSteel).accessibilityHidden(true)
      } compactTrailing: {
        BrewClock(state: context.state).font(DS.Font.mono(.footnote, .bold))
          .foregroundStyle(DS.signalOnSteel).frame(maxWidth: 52)
      } minimal: {
        Image(systemName: "cup.and.heat.waves.fill").foregroundStyle(DS.signalOnSteel)
          .accessibilityLabel("Brew timer")
      }
      .widgetURL(context.attributes.linkURL)
      .keylineTint(DS.signalOnSteel)
    }
  }
}

/// Elapsed brew time. Frozen at `pausedAt` while paused.
struct BrewClock: View {
  let state: TimerActivityAttributes.ContentState

  var body: some View {
    Text(
      timerInterval: state.startDate...state.endDate, pauseTime: state.pausedAt, showsHours: false
    )
    .monospacedDigit().multilineTextAlignment(.trailing)
  }
}

struct StepLine: View {
  let attributes: TimerActivityAttributes
  let state: TimerActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      Text(
        "STEP \(max(state.stepNumber, 1)) OF \(attributes.stepCount)"
          + (state.pausedAt == nil ? "" : " · PAUSED")
      )
      .font(DS.Font.mono(.caption, .bold)).foregroundStyle(DS.onSteel)
      Text(state.stepLabel).font(DS.Font.headline).foregroundStyle(DS.onSteel)
      if let next = state.nextLabel {
        Text("Next: \(next)").font(.footnote).foregroundStyle(DS.onSteel.opacity(0.8))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

struct LockScreenTimer: View {
  let attributes: TimerActivityAttributes
  let state: TimerActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack(alignment: .firstTextBaseline) {
        Text(attributes.recipeName.uppercased()).font(DS.Font.label)
          .foregroundStyle(DS.onSteel).lineLimit(1)
        Spacer(minLength: DS.Space.sm)
        BrewClock(state: state).font(DS.Font.mono(.title, .bold))
          .foregroundStyle(DS.signalOnSteel).frame(maxWidth: 120, alignment: .trailing)
      }
      StepLine(attributes: attributes, state: state)
    }
    .padding(DS.Space.lg)
  }
}
