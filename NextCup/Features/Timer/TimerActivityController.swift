import ActivityKit
import Foundation
import NextCupKit

extension TimerActivityAttributes.ContentState {
  /// `nil` when there is nothing to show: before the start and after the end.
  /// With `plan`, steps that start together count as one, as on the timer screen.
  init?(state: TimerState, plan: TimerPlan? = nil, now: Date) {
    switch state.phase {
    case .notStarted, .finished: return nil
    case .running, .paused: break
    }
    let start = now.addingTimeInterval(-state.elapsedS)
    self.init(
      stepLabel: state.current?.label ?? "Ready",
      nextLabel: (plan.map { $0.nextDisplayedStep(after: state) } ?? state.next)?.label,
      stepNumber: (state.currentIndex.map { plan?.groupIndex(ofStep: $0) ?? $0 } ?? -1) + 1,
      startDate: start,
      endDate: start.addingTimeInterval(Double(state.totalDurationS)),
      pausedAt: state.phase == .paused ? now : nil)
  }
}

extension TimerActivityAttributes {
  init(setup: TimerSetup) {
    self.init(
      recipeName: setup.recipeName, methodName: setup.methodName,
      stepCount: setup.plan.displayGroups.count,
      linkURL: DeepLink.timer(recipeID: setup.recipeID, doseG: setup.scaled.doseG).url)
  }
}

/// Mirrors the running timer to a Live Activity. Failures never stop the brew.
@MainActor
protocol TimerActivityControlling {
  func update(setup: TimerSetup, state: TimerState)
  func end()
}

/// UI tests and previews: no activity.
@MainActor
struct NoTimerActivity: TimerActivityControlling {
  func update(setup: TimerSetup, state: TimerState) {}
  func end() {}
}

/// ActivityKit's `Activity` is not `Sendable` in this SDK, yet only its own async calls
/// touch it, and this class is its only user.
private struct ActivityHandle: @unchecked Sendable {
  let activity: Activity<TimerActivityAttributes>
}

@MainActor
final class LiveTimerActivity: TimerActivityControlling {
  private var activity: Activity<TimerActivityAttributes>?

  func update(setup: TimerSetup, state: TimerState) {
    guard
      let content = TimerActivityAttributes.ContentState(
        state: state, plan: setup.plan, now: Date())
    else {
      end()
      return
    }
    // A relaunch adopts the activity the last process started instead of stacking a second.
    activity = activity ?? Activity<TimerActivityAttributes>.activities.first
    let activityContent = ActivityContent(state: content, staleDate: content.endDate)
    if let activity {
      let handle = ActivityHandle(activity: activity)
      Task { await handle.activity.update(activityContent) }
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    activity = try? Activity.request(
      attributes: TimerActivityAttributes(setup: setup), content: activityContent)
  }

  func end() {
    let running = activity.map { [$0] } ?? Activity<TimerActivityAttributes>.activities
    activity = nil
    for activity in running {
      let handle = ActivityHandle(activity: activity)
      Task { await handle.activity.end(nil, dismissalPolicy: .immediate) }
    }
  }
}
